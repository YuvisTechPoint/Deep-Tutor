# Vercel Bundle Size Optimization

## Changes Made

### 1. **vercel.json** — Removed Custom Install Command
- Uses standard `npm ci --prefer-offline` for better dependency caching
- Configured for optimal memory allocation
- Added rewrites and headers for better performance

### 2. **.vercelignore** — Excluded Unnecessary Files
- Removed development files, tests, and documentation
- Excluded Python backend files
- Optimized for frontend-only deployment

### 3. **web/next.config.js** — Added Production Optimizations
- Enabled `swcMinify` for better JS minification
- Disabled source maps in production
- Added image optimization with AVIF/WebP formats
- Configured webpack for tree-shaking and code splitting

### 4. **web/.npmrc** — Optimized npm Behavior
- `production=true` - Skip devDependencies install
- `prefer-offline=true` - Use cache when possible
- `legacy-peer-deps=true` - Handle peer dependency conflicts

## Bundle Size Reduction Strategies

### Heavy Dependencies to Review:
1. **firebase** (Large library)
   - Consider lazy loading if possible
   - Or switch to Firebase compat library

2. **@supabase/supabase-js** (Substantial)
   - Only import needed modules
   - Use tree-shaking friendly imports

3. **mermaid** (Large diagram library)
   - Lazy load with dynamic imports
   - Consider mermaid-lite alternative for basic diagrams

4. **html2canvas + jspdf** (Export features)
   - Lazy load these only when needed
   - Use dynamic imports in components

### Implementation Steps:

#### Step 1: Lazy Load Heavy Libraries
```typescript
// Instead of top-level imports, use dynamic imports
import dynamic from 'next/dynamic';

const MermaidDiagram = dynamic(() => import('@/components/MermaidDiagram'), {
  loading: () => <div>Loading...</div>,
});

const PdfExporter = dynamic(() => import('@/lib/pdf-export'), {
  ssr: false,
});
```

#### Step 2: Remove Unused Dependencies
```bash
# Identify unused dependencies
npm prune

# Check for duplicates
npm ls --all
```

#### Step 3: Test Bundle Size Locally
```bash
npm run build
npx next/dist/bin/next export  # For static analysis
```

#### Step 4: Monitor on Vercel
Check Vercel Analytics dashboard after deployment for bundle insights.

## Expected Improvements

- **Before**: 448.87 MB
- **Target**: < 245 MB
- **Target Reduction**: ~45%

This should be achievable by:
1. Removing custom install (10-15 MB)
2. Excluding backend/test files (20-30 MB)
3. Tree-shaking and minification (15-25 MB)
4. Lazy loading heavy libraries (30-50 MB)

## Deployment Instructions

1. Push changes to GitHub
2. Vercel will auto-detect `vercel.json`
3. Monitor build logs for bundle warnings
4. Check Vercel Analytics after deployment

## Additional Notes

- The `.vercelignore` file tells Vercel which files to exclude
- `npm ci` is preferred over `npm install` for deterministic builds
- Next.js standalone output reduces runtime dependencies
- Consider implementing dynamic imports for large UI components
