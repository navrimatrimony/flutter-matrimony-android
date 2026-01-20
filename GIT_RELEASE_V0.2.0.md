# Git Release v0.2.0 Stable - Commands

## Step-by-Step Commands to Run:

```powershell
# Navigate to project directory
cd "e:\LaravelProjects\FLUTTER MATRIMONY APP\flutter-matrimony-android"

# 1. Add all changes (including updated pubspec.yaml)
git add .

# 2. Commit with release message
git commit -m "Release v0.2.0 Stable: Flutter Matrimony App Phase 1 Complete

Features:
- Complete authentication flow (Login/Register)
- Profile creation and management
- Browse profiles with search filters (Age, Caste, Location)
- Interest system (send/receive/accept/reject/withdraw)
- Dashboard with interest statistics
- Unified hero image design (blurred background + clear foreground)
- Brand: नवरी मिळे नवऱ्याला
- Release APK ready (48MB)
- Multi-device compatible (Android 5.0+)
- All scrolling issues fixed
- Send Interest button visibility fixed"

# 3. Create annotated tag for v0.2.0
git tag -a v0.2.0 -m "Stable Release v0.2.0

Flutter Matrimony App - Phase 1 Complete
Brand: नवरी मिळे नवऱ्याला
Version: 0.2.0+1
Release Date: $(Get-Date -Format 'yyyy-MM-dd')

Key Features:
- Authentication (Login/Register)
- Profile Management
- Browse with Filters
- Interest System
- Dashboard Statistics
- Hero Image Design
- Multi-device Support"

# 4. Push code to main branch
git push origin main

# 5. Push tag to remote
git push origin v0.2.0

# 6. Verify tag was pushed
git ls-remote --tags origin
```

## Verification:

After pushing, verify:
```powershell
# Check local tags
git tag

# Check remote tags
git ls-remote --tags origin

# View tag details
git show v0.2.0
```

## Status:
✅ Version updated: 0.2.0+1
✅ Ready for commit and tag
