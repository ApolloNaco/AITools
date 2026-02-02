#!/bin/bash
# 使用说明 把这个脚本放在你windows的D盘下的/Ai/shell/文件夹下然后在对应项目的git bash命令行中执行即可
#  bash /d/Ai/shell/cursor_sync.sh

# ================= 配置项（按需修改） =================
GIT_REPO="https://github.com/ApolloNaco/AITools.git"
BRANCH="master"                 # 要拉取的分支，默认 master
REMOTE_DIR="cursor/commands"     # 仓库里要同步的目录（与远端结构一致）
LOCAL_DIR=".cursor/commands"     # 当前项目下的目标目录

# ================= 直接拉 =================
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "== Cursor Sync: $REMOTE_DIR -> $LOCAL_DIR (branch: $BRANCH) =="
git clone --depth=1 -b "$BRANCH" "$GIT_REPO" "$TEMP_DIR" || exit 1

# 实际仓库根：克隆后可能是 TEMP_DIR 或 TEMP_DIR/仓库名（视 Git 行为而定）
REPO_NAME="$(basename "$GIT_REPO" .git)"
if [ -d "$TEMP_DIR/$REMOTE_DIR" ]; then
  CLONE_ROOT="$TEMP_DIR"
elif [ -d "$TEMP_DIR/$REPO_NAME/$REMOTE_DIR" ]; then
  CLONE_ROOT="$TEMP_DIR/$REPO_NAME"
else
  echo "ERROR: Remote directory not found: $REMOTE_DIR"
  echo ""
  echo "Actual structure under temp dir:"
  find "$TEMP_DIR" -maxdepth 3 -type d | sed "s|$TEMP_DIR/||g" | grep -v "^\.git" | sort
  echo ""
  echo "Tip: Set REMOTE_DIR in script to one of the paths above (relative to repo root)."
  exit 1
fi

REMOTE_PATH="$CLONE_ROOT/$REMOTE_DIR"

echo ""
echo "Sync '$REMOTE_DIR' -> '$LOCAL_DIR'? [y/N]"
read -r sync_choice
if [[ "$sync_choice" != "y" && "$sync_choice" != "Y" ]]; then
  echo "Skipped."
  exit 0
fi

mkdir -p "$LOCAL_DIR"

# 统计文件变更
NEW_FILES=0
UPDATED_FILES=0
UNCHANGED_FILES=0

echo ""
echo "Processing files..."

# 遍历远程目录中的所有文件
while IFS= read -r -d '' remote_file; do
  # 获取相对路径
  rel_path="${remote_file#$REMOTE_PATH/}"
  local_file="$LOCAL_DIR/$rel_path"
  
  if [ -f "$local_file" ]; then
    # 文件存在，检查是否有变化
    if ! cmp -s "$remote_file" "$local_file"; then
      echo "  [UPDATE] $rel_path"
      cp "$remote_file" "$local_file"
      ((UPDATED_FILES++))
    else
      ((UNCHANGED_FILES++))
    fi
  else
    # 新文件
    echo "  [NEW]    $rel_path"
    mkdir -p "$(dirname "$local_file")"
    cp "$remote_file" "$local_file"
    ((NEW_FILES++))
  fi
done < <(find "$REMOTE_PATH" -type f -print0)

echo ""
echo "=== Sync Summary ==="
echo "  New files:       $NEW_FILES"
echo "  Updated files:   $UPDATED_FILES"
echo "  Unchanged files: $UNCHANGED_FILES"
echo "  Total synced:    $((NEW_FILES + UPDATED_FILES + UNCHANGED_FILES))"
echo ""
echo "Done: $LOCAL_DIR"
