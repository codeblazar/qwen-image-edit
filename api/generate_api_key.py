"""
Generate a secure API key for the Qwen Image Edit API
"""
import secrets

print("=" * 60)
print("QWEN IMAGE EDIT API - SECURE KEY GENERATOR")
print("=" * 60)
print()
print("Generated API Key:")
print(secrets.token_urlsafe(32))
print()
print("To use this key:")
print("1. Copy the key above")
print("2. Set environment variable: $env:QWEN_API_KEY='your-key-here'")
print("3. Or create a .env file with: QWEN_API_KEY=your-key-here")
print("4. Restart the API server")
print()
print("In requests, include header: X-API-Key: your-key-here")
print("=" * 60)
