# Frontend & Mobile

Component architecture, state management, and rendering patterns.

## React (18+/19)

| Area | Pattern |
|------|---------|
| Components | Functional components with hooks; Server Components (RSC) |
| State | useState for local; Context/Zustand/Redux for shared |
| Forms | React 19 useActionState; or React Hook Form |
| Data | TanStack Query for server state; `use()` hook (React 19) |
| Performance | React.memo, useMemo, useCallback; React.lazy for code splitting |

**Server Components (Next.js App Router)**:
```tsx
// app/users/page.tsx — Server Component (no "use client")
export default async function UsersPage() {
  const users = await db.user.findMany();
  return <ul>{users.map(u => <li key={u.id}>{u.name}</li>)}</ul>;
}
```

**Client Form (React 19)**:
```tsx
'use client';
import { useActionState } from 'react';

export function GreetForm() {
  const [message, action, isPending] = useActionState(submitForm, '');
  return (
    <form action={action}>
      <input name="name" required />
      <button disabled={isPending}>{isPending ? 'Sending...' : 'Submit'}</button>
      {message && <p>{message}</p>}
    </form>
  );
}
```

### Key Rules
- Use `key` props correctly (stable, unique identifiers — never array index for dynamic lists)
- Clean up effects (return cleanup function from useEffect)
- Use semantic HTML and ARIA for accessibility
- Error boundaries in production for graceful failures

## Next.js (App Router)

| Area | Pattern |
|------|---------|
| Routing | File-based, app/ directory, layout.tsx + page.tsx |
| Rendering | Server Components default; "use client" for interactivity |
| Data | Server-side fetch in RSC; Server Actions for mutations |
| Caching | fetch cache, revalidatePath, revalidateTag |

## Vue 3 (Composition API)

| Area | Pattern |
|------|---------|
| State | ref() for primitives, reactive() for objects |
| Store | Pinia with defineStore |
| Composables | `use*` functions for reusable logic |

## Angular (Standalone)

| Area | Pattern |
|------|---------|
| Components | Standalone components (no NgModule) |
| Signals | signal(), computed(), effect() for reactivity |
| DI | inject() function over constructor injection |

## Mobile

| Framework | Key Focus |
|-----------|-----------|
| React Native | Expo, React Navigation, platform-specific code |
| Flutter | Widgets, BLoC/Riverpod state, Material/Cupertino |
