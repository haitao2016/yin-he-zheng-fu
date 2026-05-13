# Security

Secure coding practices, OWASP prevention, and security architecture.

## OWASP Top 10 Prevention

| Vulnerability | Prevention |
|--------------|------------|
| A01 Broken Access Control | RBAC/ABAC, deny by default, test privilege escalation |
| A02 Cryptographic Failures | TLS everywhere, bcrypt/argon2 for passwords, AES-256-GCM for data |
| A03 Injection | Parameterized queries, ORM, input validation |
| A04 Insecure Design | Threat modeling, security requirements, abuse cases |
| A05 Security Misconfiguration | Hardened defaults, remove unused features, security headers |
| A06 Vulnerable Components | Dependency scanning, SCA tools, update policy |
| A07 Auth Failures | MFA, rate limiting, session management, secure password storage |
| A08 Data Integrity Failures | Signed updates, CI/CD integrity, dependency verification |
| A09 Logging Failures | Security event logging, audit trails, monitoring |
| A10 SSRF | URL allowlists, disable redirects, network segmentation |

## Authentication

### Password Hashing
```javascript
import bcrypt from 'bcrypt';
const SALT_ROUNDS = 12;

export async function hashPassword(plaintext: string): Promise<string> {
  return bcrypt.hash(plaintext, SALT_ROUNDS);
}

export async function verifyPassword(plaintext: string, hash: string): Promise<boolean> {
  return bcrypt.compare(plaintext, hash);
}
```

### JWT Verification
```javascript
import jwt from 'jsonwebtoken';
const JWT_SECRET = process.env.JWT_SECRET\!;

export function verifyToken(token: string): jwt.JwtPayload {
  return jwt.verify(token, JWT_SECRET, {
    algorithms: ['HS256'],
    issuer: 'your-app',
    audience: 'your-app',
  }) as jwt.JwtPayload;
}
```

## Input Validation
```javascript
import { z } from 'zod';

const LoginSchema = z.object({
  email: z.string().email().max(254),
  password: z.string().min(8).max(128),
});

export function validateLoginInput(raw: unknown) {
  const result = LoginSchema.safeParse(raw);
  if (\!result.success) {
    throw new Error('Invalid credentials format');
  }
  return result.data;
}
```

## Security Headers

```javascript
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

app.use(helmet());
app.use(express.json({ limit: '10kb' }));

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
});
app.post('/api/login', authLimiter, loginHandler);
```

## Rules

### Always
- Hash passwords with bcrypt/argon2 (never MD5/SHA-1)
- Use parameterized queries (never string interpolation)
- Validate and sanitize all user input
- Set security headers (CSP, HSTS, X-Frame-Options)
- Store secrets in environment variables or secret managers
- Log security events (failed auth, privilege escalation)

### Never
- Store passwords in plaintext
- Trust user input without validation
- Expose sensitive data in logs or errors
- Use weak algorithms (MD5, SHA-1, DES, ECB)
- Hardcode secrets in code
- Return different errors for "user not found" vs "wrong password"
