#!/usr/bin/env bash

# Deterministic executable specification for normalized Symphony controller
# observations. This models decisions only; it performs no provider operation.

emit_action_plan() {
  local category=$1 reads=$2 mutations=$3 events=$4 suppressed=$5 next=$6
  printf 'category\t%s\n' "$category"
  printf 'required_reads\t%s\n' "$reads"
  printf 'allowed_mutations\t%s\n' "$mutations"
  printf 'journal_events\t%s\n' "$events"
  printf 'suppressed_actions\t%s\n' "$suppressed"
  printf 'next_state_verdict\t%s\n' "$next"
}

attached_cleanup_is_safe() {
  [[ "$1" == "proved" &&
     "$2" == "match" &&
     "$3" == "match" &&
     "$4" == "attached-worktree" &&
     "$5" == "match" &&
     "$6" == "expected" ]]
}

unattached_cleanup_is_safe() {
  [[ "$1" == "proved" &&
     "$2" == "match" &&
     "$3" == "match" &&
     "$4" == "reserved-unattached" &&
     "$5" == "absent" &&
     "$6" == "absent" &&
     "$7" == "expected" ]]
}

emit_validation_timeout_plan() {
  local cleanup_kind=$1 attempts=$2 state_changed=$3 state_observation=$4
  local exhaustion_event=$5 retry_identity=$6
  local reads mutations events suppressed next

  case "$cleanup_kind" in
    attached)
      reads=command-process,cleanup-ledger,owned-path,canonical-path,ownership-marker,attachment-state,git-worktree-metadata,directory-contents
      mutations=terminate-command,git-worktree-remove,filesystem-remove-transients
      events=action-failed
      suppressed=review-publication
      next=inconclusive-cleanup-complete
      ;;
    unattached)
      reads=command-process,cleanup-ledger,owned-path,canonical-path,ownership-marker,attachment-state,repository-metadata,directory-contents
      mutations=terminate-command,filesystem-remove-reservation
      events=action-failed
      suppressed=review-publication,git-worktree-remove
      next=inconclusive-cleanup-complete
      ;;
    *)
      reads=command-process,cleanup-ledger,owned-path,canonical-path,ownership-marker,attachment-state,repository-metadata,directory-contents
      mutations=terminate-command
      events=action-failed,cleanup-failed
      suppressed=review-publication,filesystem-delete,git-worktree-remove
      next=inconclusive-cleanup-debt-retain-exact-path
      ;;
  esac

  if [[ "$attempts" == "exhausted" &&
        "$state_changed" == "true" &&
        "$state_observation" == "confirmed" &&
        "$exhaustion_event" == "recorded" &&
        "$retry_identity" == "stable" ]]; then
    reads+=,action-journal,fresh-native-state,relevant-state,stable-action-identity
    if [[ "$cleanup_kind" == "unsafe" ]]; then
      suppressed+=,bounded-retry-until-cleanup-safe,duplicate-retry-exhausted,unbounded-retry
      next+=-before-bounded-retry
    else
      mutations+=,resume-prior-phase,bounded-retry
      suppressed+=,duplicate-retry-exhausted,unbounded-retry
      next+=-retry-after-confirmed-state-change
    fi
  elif [[ "$attempts" == "exhausted" ]]; then
    reads+=,action-journal,relevant-state
    suppressed+=,further-mutation
    next+=-needs-human
    if [[ "$state_changed" == "false" &&
          "$exhaustion_event" == "absent" ]]; then
      mutations+=,apply-needs-human
      events+=,retry-exhausted
    fi
  fi

  emit_action_plan validation-timeout "$reads" "$mutations" "$events" \
    "$suppressed" "$next"
}

reduce_controller_state() {
  local normalized_state=$1 entry key value cleanup_kind
  local -a entries=()
  local -A predicate=()

  IFS=';' read -r -a entries <<< "$normalized_state"
  for entry in "${entries[@]}"; do
    key=${entry%%=*}
    value=${entry#*=}
    if [[ -z "$key" || "$entry" == "$key" ]]; then
      emit_action_plan permanent-invalid normalized-state none action-failed \
        all-mutation needs-human
      return
    fi
    if [[ -n "${predicate[$key]+present}" &&
          "${predicate[$key]}" != "$value" ]]; then
      emit_action_plan permanent-invalid normalized-state none action-failed \
        all-mutation needs-human
      return
    fi
    predicate["$key"]=$value
  done

  if [[ "${predicate[surface]:-}" == "validation" &&
        "${predicate[command]:-}" == "timed-out" ]]; then
    if [[ "${predicate[owned_path]:-}" == "known" ]] &&
       attached_cleanup_is_safe \
         "${predicate[containment]:-}" "${predicate[marker]:-}" \
         "${predicate[action_identity]:-}" "${predicate[attachment]:-}" \
         "${predicate[git_metadata]:-}" "${predicate[contents]:-}"; then
      cleanup_kind=attached
    elif [[ "${predicate[owned_path]:-}" == "known" ]] &&
         unattached_cleanup_is_safe \
           "${predicate[containment]:-}" "${predicate[marker]:-}" \
           "${predicate[action_identity]:-}" "${predicate[attachment]:-}" \
           "${predicate[git_metadata]:-}" "${predicate[checkout]:-}" \
           "${predicate[contents]:-}"; then
      cleanup_kind=unattached
    else
      cleanup_kind=unsafe
    fi
    emit_validation_timeout_plan "$cleanup_kind" \
      "${predicate[attempts]:-}" "${predicate[state_changed]:-}" \
      "${predicate[state_change_observation]:-}" \
      "${predicate[exhaustion_event]:-}" "${predicate[retry_identity]:-}"
  elif [[ "${predicate[attempts]:-}" == "exhausted" &&
        "${predicate[state_changed]:-}" == "true" &&
        "${predicate[state_change_observation]:-}" == "confirmed" &&
        "${predicate[exhaustion_event]:-}" == "recorded" &&
        "${predicate[action_identity]:-}" == "stable" ]]; then
    emit_action_plan "${predicate[failure]:-permanent-invalid}" \
      action-journal,fresh-native-state,relevant-state,stable-action-identity \
      resume-prior-phase,bounded-retry none \
      duplicate-retry-exhausted,unbounded-retry \
      retry-after-confirmed-state-change
  elif [[ "${predicate[attempts]:-}" == "exhausted" &&
        "${predicate[state_changed]:-}" == "false" &&
        "${predicate[exhaustion_event]:-}" == "absent" ]]; then
    emit_action_plan "${predicate[failure]:-permanent-invalid}" \
      action-journal,relevant-state apply-needs-human retry-exhausted \
      further-mutation needs-human
  elif [[ "${predicate[attempts]:-}" == "exhausted" ]]; then
    emit_action_plan "${predicate[failure]:-permanent-invalid}" \
      action-journal,relevant-state none none further-mutation needs-human
  elif [[ "${predicate[surface]:-}" == "linear" &&
          "${predicate[observation]:-}" == "partial" &&
          "${predicate[native_id]:-}" == "known" ]]; then
    emit_action_plan observation-incomplete linear-native-id none action-failed \
      dependent-mutation retry-read
  elif [[ "${predicate[surface]:-}" == "linear" &&
          "${predicate[create_outcome]:-}" == "ambiguous" &&
          "${predicate[action_identity]:-}" == "unresolved" ]]; then
    emit_action_plan mutation-ambiguous linear-action-identity-search none \
      action-failed repeat-create resolve-ambiguous-creation
  elif [[ "${predicate[surface]:-}" == "github" &&
          "${predicate[publication]:-}" == "pending" &&
          "${predicate[pr_head]:-}" == "stale" ]]; then
    emit_action_plan review-stale-head github-pr-head,linear-contract-dag \
      cleanup-owned-resource review-stale-head review-publication review-new-head
  elif [[ "${predicate[surface]:-}" == "github" &&
          "${predicate[formal_review]:-}" == "denied-same-identity" ]]; then
    emit_action_plan none github-review-permission github-top-level-comment \
      review-recorded github-formal-review review-recorded
  elif [[ "${predicate[surface]:-}" == "cursor" &&
          "${predicate[delegation]:-}" == "fresh-existing" ]]; then
    emit_action_plan already-dispatched linear-delegation-state none none \
      cursor-delegation observe-existing-dispatch
  elif [[ "${predicate[surface]:-}" == "cursor" &&
          "${predicate[integration]:-}" == "unavailable" ]]; then
    emit_action_plan cursor-unavailable cursor-integration-target none \
      action-failed affected-cursor-dispatch affected-dispatch-paused
  elif [[ "${predicate[surface]:-}" == "cleanup" &&
          "${predicate[marker]:-}" == "mismatch" ]]; then
    emit_action_plan cleanup-failed canonical-path,ownership-marker none \
      cleanup-failed filesystem-delete,git-worktree-remove cleanup-debt
  elif [[ "${predicate[surface]:-}" == "github" &&
          "${predicate[ci]:-}" == "pending" ]]; then
    emit_action_plan none github-checks none none \
      failure-journal,merge-ready-transition,retry-journal waiting-ci
  elif [[ "${predicate[surface]:-}" == "controller" &&
          "${predicate[capacity]:-}" == "full" ]]; then
    emit_action_plan none active-cursor-count none none \
      cursor-dispatch,failure-journal,retry-journal capacity-wait
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[proposal]:-}" == "recorded" &&
          "${predicate[approval]:-}" == "absent" ]]; then
    emit_action_plan none dag-proposed,dag-approved none none \
      dag-materialization awaiting-dag-approval
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[approval]:-}" == "recorded" &&
          "${predicate[node_bindings]:-}" == "partial" &&
          "${predicate[edge_bindings]:-}" == "partial" ]]; then
    emit_action_plan none \
      dag-approved,dag-node-bound,dag-edge-bound,native-bindings \
      linear-create-missing-node,linear-create-missing-edge \
      dag-node-bound,dag-edge-bound,dag-materialized \
      recreate-bound-native-object dag-materialized
  elif [[ "${predicate[surface]:-}" == "reconciler" &&
          "${predicate[merge]:-}" == "observed" &&
          "${predicate[verdict]:-}" == "human-decision" ]]; then
    emit_action_plan none merge-observation,reconciliation-evidence \
      apply-needs-human merge-observed,human-decision-required \
      completion,downstream-unlock human-decision
  elif [[ "${predicate[surface]:-}" == "reconciler" &&
          "${predicate[merge]:-}" == "observed" &&
          "${predicate[verdict]:-}" == "inconclusive" ]]; then
    emit_action_plan observation-incomplete \
      merge-observation,reconciliation-evidence none \
      merge-observed,action-failed completion,downstream-unlock \
      inconclusive-bounded-retry
  elif [[ "${predicate[surface]:-}" == "cleanup" ]] &&
       unattached_cleanup_is_safe \
         "${predicate[containment]:-}" "${predicate[marker]:-}" \
         "${predicate[action_identity]:-}" "${predicate[attachment]:-}" \
         "${predicate[git_metadata]:-}" "${predicate[checkout]:-}" \
         "${predicate[contents]:-}"; then
    emit_action_plan none \
      canonical-path,ownership-marker,attachment-state,repository-metadata,directory-contents \
      filesystem-remove-reservation none git-worktree-remove cleanup-complete
  elif [[ "${predicate[surface]:-}" == "cleanup" ]] &&
       attached_cleanup_is_safe \
         "${predicate[containment]:-}" "${predicate[marker]:-}" \
         "${predicate[action_identity]:-}" "${predicate[attachment]:-}" \
         "${predicate[git_metadata]:-}" "${predicate[contents]:-}"; then
    emit_action_plan none \
      canonical-path,ownership-marker,attachment-state,git-worktree-metadata,directory-contents \
      git-worktree-remove,filesystem-remove-transients none none cleanup-complete
  elif [[ "${predicate[surface]:-}" == "cleanup" ]]; then
    emit_action_plan cleanup-failed \
      canonical-path,ownership-marker,attachment-state,repository-metadata,directory-contents \
      none cleanup-failed filesystem-delete,git-worktree-remove cleanup-debt
  else
    emit_action_plan permanent-invalid normalized-state none action-failed \
      all-mutation needs-human
  fi
}
