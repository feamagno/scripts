#!/usr/bin/env bash

CURRENT_PATH="$PWD"

# -type d tells find to only return directories
find $CURRENT_PATH -name ".git" -type d -prune | while read -r gitdir; do
    
    repo_dir=$(dirname "$gitdir")

    cd "$repo_dir" || continue

    echo "------"
    echo "found repo: $repo_dir"

    git fetch --quiet

    LOCAL=$(git rev-parse @ 2>/dev/null) #where I am
    REMOTE=$(git rev-parse @{u} 2>/dev/null) #where remote is
    BASE=$(git rev-parse @ @{u} 2>/dev/null) #where we agree

    # 3. Compare them
    if [ -z "$REMOTE" ]; then
        echo "slc parca tem nada de git remote aqui"
    elif [ "$LOCAL" = "$REMOTE" ]; then
        echo "aqui ta suave"
    elif [ "$LOCAL" = "$BASE" ]; then
        BEHIND_COUNT=$(git rev-list --count HEAD..@{u})
        echo "ihhhh carai ta c atraso de $BEHIND_COUNT bora arruma isso"
    elif [ "$REMOTE" = "$BASE" ]; then
        AHEAD_COUNT=$(git rev-list --count @{u}..HEAD)
        echo "aiii tu eh todo pra frentex neh? ta: $AHEAD_COUNT na frente"
    else
        echo "vixe truta deu treta legal aqui, divergiu mto"
    fi

done
