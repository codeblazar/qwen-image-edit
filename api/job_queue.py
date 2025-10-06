"""
Job queue system for handling concurrent API requests from multiple stations
"""
import asyncio
from datetime import datetime
from typing import Optional, Dict, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import uuid


class JobStatus(str, Enum):
    """Job status enumeration"""
    QUEUED = "queued"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class Job:
    """Represents a single image editing job"""
    job_id: str
    instruction: str
    image_data: bytes
    model: Optional[str] = None
    seed: Optional[int] = None
    system_prompt: Optional[str] = None
    status: JobStatus = JobStatus.QUEUED
    created_at: datetime = field(default_factory=datetime.now)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    result_path: Optional[str] = None
    result_seed: Optional[int] = None
    error: Optional[str] = None
    position: int = 0  # Position in queue


class JobQueue:
    """
    Manages a queue of image editing jobs with configurable limits
    
    Features:
    - FIFO queue processing
    - Max queue size limit (default 10)
    - Job status tracking
    - Automatic cleanup of old completed jobs
    """
    
    def __init__(self, max_size: int = 10, cleanup_age_seconds: int = 3600):
        """
        Initialize job queue
        
        Args:
            max_size: Maximum number of jobs in queue (default 10)
            cleanup_age_seconds: Age in seconds before completed jobs are cleaned (default 1 hour)
        """
        self.max_size = max_size
        self.cleanup_age_seconds = cleanup_age_seconds
        
        self.queue: asyncio.Queue = asyncio.Queue(maxsize=max_size)
        self.jobs: Dict[str, Job] = {}  # job_id -> Job
        self.current_job: Optional[Job] = None
        self.process_callback: Optional[Callable] = None  # Callback to process jobs
        
        self._worker_task: Optional[asyncio.Task] = None
        self._cleanup_task: Optional[asyncio.Task] = None
        self._running = False
    
    def start(self):
        """Start the queue worker and cleanup tasks"""
        if not self._running:
            self._running = True
            # Worker task will be started when first job is submitted
            # Cleanup task runs periodically
            self._cleanup_task = asyncio.create_task(self._cleanup_old_jobs())
            print(f"[JobQueue] Started - Max size: {self.max_size}, Cleanup age: {self.cleanup_age_seconds}s")
    
    async def stop(self):
        """Stop the queue worker and cleanup tasks"""
        self._running = False
        
        if self._worker_task:
            self._worker_task.cancel()
            try:
                await self._worker_task
            except asyncio.CancelledError:
                pass
        
        if self._cleanup_task:
            self._cleanup_task.cancel()
            try:
                await self._cleanup_task
            except asyncio.CancelledError:
                pass
        
        print("[JobQueue] Stopped")
    
    async def submit_job(
        self,
        instruction: str,
        image_data: bytes,
        model: Optional[str] = None,
        seed: Optional[int] = None,
        system_prompt: Optional[str] = None
    ) -> Job:
        """
        Submit a new job to the queue
        
        Args:
            instruction: Editing instruction
            image_data: Image bytes
            model: Model to use (if None, uses currently loaded model)
            seed: Random seed
            system_prompt: Optional system prompt
            
        Returns:
            Job object with job_id
            
        Raises:
            asyncio.QueueFull: If queue is at max capacity
        """
        # Check if queue is full
        if self.queue.full():
            raise asyncio.QueueFull(f"Queue is full (max {self.max_size} jobs)")
        
        # Create job
        job_id = str(uuid.uuid4())
        job = Job(
            job_id=job_id,
            instruction=instruction,
            image_data=image_data,
            model=model,
            seed=seed,
            system_prompt=system_prompt,
            status=JobStatus.QUEUED,
            position=self.queue.qsize() + 1
        )
        
        # Add to queue and tracking
        await self.queue.put(job)
        self.jobs[job_id] = job
        
        # Start worker if not running
        if not self._worker_task or self._worker_task.done():
            self._worker_task = asyncio.create_task(self._process_queue())
        
        print(f"[JobQueue] Job {job_id[:8]} submitted - Queue size: {self.queue.qsize()}")
        
        return job
    
    def get_job(self, job_id: str) -> Optional[Job]:
        """Get job by ID"""
        return self.jobs.get(job_id)
    
    def get_queue_status(self) -> Dict[str, Any]:
        """Get current queue status"""
        queued_jobs = [j for j in self.jobs.values() if j.status == JobStatus.QUEUED]
        processing_jobs = [j for j in self.jobs.values() if j.status == JobStatus.PROCESSING]
        completed_jobs = [j for j in self.jobs.values() if j.status == JobStatus.COMPLETED]
        failed_jobs = [j for j in self.jobs.values() if j.status == JobStatus.FAILED]
        
        return {
            "queue_size": self.queue.qsize(),
            "max_queue_size": self.max_size,
            "queued_count": len(queued_jobs),
            "processing_count": len(processing_jobs),
            "completed_count": len(completed_jobs),
            "failed_count": len(failed_jobs),
            "current_job_id": self.current_job.job_id if self.current_job else None,
            "total_jobs": len(self.jobs)
        }
    
    async def _process_queue(self):
        """Background worker that processes jobs from the queue"""
        print("[JobQueue] Worker started")
        
        while self._running:
            try:
                # Get next job (wait up to 1 second)
                try:
                    job = await asyncio.wait_for(self.queue.get(), timeout=1.0)
                except asyncio.TimeoutError:
                    continue
                
                # Update job status
                job.status = JobStatus.PROCESSING
                job.started_at = datetime.now()
                self.current_job = job
                
                # Update positions of remaining queued jobs
                self._update_queue_positions()
                
                print(f"[JobQueue] Processing job {job.job_id[:8]} - {job.instruction[:50]}...")
                
                # The actual image generation will be called from the worker
                # This signals that the job is ready for processing
                # The main.py startup event will inject the processing callback
                if self.process_callback:
                    try:
                        await self.process_callback(job)
                    except Exception as e:
                        print(f"[JobQueue] Job processing failed: {e}")
                        self.fail_job(job.job_id, str(e))
                else:
                    print("[JobQueue] WARNING: No process_callback set, job will not be processed")
                    self.fail_job(job.job_id, "No processing callback configured")
                
            except Exception as e:
                print(f"[JobQueue] Worker error: {e}")
                if job:
                    job.status = JobStatus.FAILED
                    job.error = str(e)
                    job.completed_at = datetime.now()
                    self.current_job = None
    
    def complete_job(self, job_id: str, result_path: str, result_seed: int):
        """Mark job as completed"""
        job = self.jobs.get(job_id)
        if job:
            job.status = JobStatus.COMPLETED
            job.completed_at = datetime.now()
            job.result_path = result_path
            job.result_seed = result_seed
            
            if self.current_job and self.current_job.job_id == job_id:
                self.current_job = None
            
            print(f"[JobQueue] Job {job_id[:8]} completed - Path: {result_path}")
    
    def fail_job(self, job_id: str, error: str):
        """Mark job as failed"""
        job = self.jobs.get(job_id)
        if job:
            job.status = JobStatus.FAILED
            job.completed_at = datetime.now()
            job.error = error
            
            if self.current_job and self.current_job.job_id == job_id:
                self.current_job = None
            
            print(f"[JobQueue] Job {job_id[:8]} failed - Error: {error}")
    
    def _update_queue_positions(self):
        """Update position numbers for queued jobs"""
        queued_jobs = sorted(
            [j for j in self.jobs.values() if j.status == JobStatus.QUEUED],
            key=lambda x: x.created_at
        )
        for i, job in enumerate(queued_jobs, start=1):
            job.position = i
    
    async def _cleanup_old_jobs(self):
        """Periodically clean up old completed/failed jobs"""
        while self._running:
            try:
                await asyncio.sleep(300)  # Run every 5 minutes
                
                now = datetime.now()
                to_remove = []
                
                for job_id, job in self.jobs.items():
                    if job.status in [JobStatus.COMPLETED, JobStatus.FAILED]:
                        if job.completed_at:
                            age = (now - job.completed_at).total_seconds()
                            if age > self.cleanup_age_seconds:
                                to_remove.append(job_id)
                
                for job_id in to_remove:
                    del self.jobs[job_id]
                    print(f"[JobQueue] Cleaned up old job {job_id[:8]}")
                
                if to_remove:
                    print(f"[JobQueue] Cleanup: Removed {len(to_remove)} old jobs")
                
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"[JobQueue] Cleanup error: {e}")


# Global job queue instance
job_queue = JobQueue(max_size=10, cleanup_age_seconds=3600)
