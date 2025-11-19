
#!/usr/bin/env bash
set -euo pipefail
MF="kernel/Makefile"
if [ ! -f "$MF" ]; then
  echo "[ERROR] $MF not found" >&2
  exit 1
fi

# Make a backup copy
cp "$MF" "$MF.bak"

has_targets_line=$(grep -nE '^[[:space:]]*targets[[:space:]]*\+=[[:space:]]*config_data\.gz' "$MF" || true)
has_rule_defconfig=$(grep -nE '^\s*\$\(obj\)/config_data\.gz:\s*arch/arm64/configs/.+-defconfig\s*FORCE' "$MF" || true)
has_rule_kconfig=$(grep -nE '^\s*\$\(obj\)/config_data\.gz:\s*\$\(KCONFIG_CONFIG\)\s*FORCE' "$MF" || true)

if [ -n "$has_rule_kconfig" ]; then
  echo "[INFO] Makefile already uses $(KCONFIG_CONFIG) for config_data.gz"
else
  if [ -n "$has_rule_defconfig" ]; then
    # Replace hardcoded defconfig with $(KCONFIG_CONFIG)
    echo "[INFO] Replacing hardcoded defconfig dependency with $(KCONFIG_CONFIG)"
    # Use sed with a conservative pattern
    sed -E -i 's|^(\s*\$\(obj\)/config_data\.gz:\s*)arch/arm64/configs/[A-Za-z0-9_.-]+-defconfig(\s*)FORCE|$(KCONFIG_CONFIG)FORCE|' "$MF"
  else
    echo "[INFO] No rule found; will insert rule using $(KCONFIG_CONFIG)"
    if [ -n "$has_targets_line" ]; then
      # Insert rule just after targets += config_data.gz
      line_no=$(echo "$has_targets_line" | head -n1 | cut -d: -f1)
      awk -v ln="$line_no" 'NR==ln {print; print "$(obj)/config_data.gz: $(KCONFIG_CONFIG) FORCE"; print "	$(call if_changed,gzip)"; next} {print}' "$MF" > "$MF.new"
      mv "$MF.new" "$MF"
    else
      # Append both targets and rule at end
      {
        echo "targets += config_data.gz"
        echo "$(obj)/config_data.gz: $(KCONFIG_CONFIG) FORCE"
        printf "	$(call if_changed,gzip)
"
      } >> "$MF"
    fi
  fi
fi

echo "[INFO] Final diff for $MF:" >&2
git --no-pager diff -- "$MF" || true
