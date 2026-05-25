# Branch Protection Setup Guide

## Quick Setup (5 minutes)

### Step 1: Navigate to Settings
1. Go to repo Settings → Branches
2. Click **Add rule**

### Step 2: Configure

**Branch name pattern:** `main`

### Step 3: Enable Protection

✅ **Require status checks to pass**
- Select: `dbt build`

✅ **Require pull request reviews**
- Required: `1` approval
- Check: "Dismiss stale approvals"

✅ **Advanced**
- Require up-to-date branches
- Block force pushes
- Block deletions

### Step 4: Save

Click **Create**

## Result

✅ CI must pass before merge  
✅ 1 approval required  
✅ No force pushes allowed  
✅ `main` branch protected
