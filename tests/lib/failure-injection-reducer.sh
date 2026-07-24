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

reservation_attached_cleanup_is_safe() {
  [[ "$1" == "proved" &&
     "$2" == "current-confirmed" &&
     "$3" == "reservation-match" &&
     "$4" == "reservation-match" &&
     "$5" == "attached-worktree" &&
     "$6" == "match" &&
     "$7" == "expected" ]]
}

reservation_unattached_cleanup_is_safe() {
  [[ "$1" == "proved" &&
     "$2" == "current-confirmed" &&
     "$3" == "reservation-match" &&
     "$4" == "reservation-match" &&
     "$5" == "reserved-unattached" &&
     "$6" == "absent" &&
     "$7" == "absent" &&
     "$8" == "expected" ]]
}

bound_review_attached_cleanup_is_safe() {
  [[ "$1" == "proved" &&
     "$2" == "current-confirmed" &&
     "$3" == "reservation-action-match" &&
     "$4" == "bound-match" &&
     "$5" == "current-match" &&
     "$6" == "attached-worktree" &&
     "$7" == "match" &&
     "$8" == "expected" ]]
}

bound_review_unattached_cleanup_is_safe() {
  [[ "$1" == "proved" &&
     "$2" == "current-confirmed" &&
     "$3" == "reservation-action-match" &&
     "$4" == "bound-match" &&
     "$5" == "current-match" &&
     "$6" == "reserved-unattached" &&
     "$7" == "absent" &&
     "$8" == "absent" &&
     "$9" == "expected" ]]
}

retry_pause_identity_is_canonical() {
  local entity_uuid=$1 action_identity=$2 failure_category=$3
  local prior_phase=$4 resume_phase=$5 observed_identity=$6
  local canonical digest encoded_entity encoded_action encoded_failure
  local encoded_prior encoded_resume

  [[ -n "$entity_uuid" && -n "$action_identity" &&
     -n "$failure_category" && -n "$prior_phase" &&
     -n "$resume_phase" && -n "$observed_identity" ]] || return 1
  encoded_entity=$(json_string "$entity_uuid")
  encoded_action=$(json_string "$action_identity")
  encoded_failure=$(json_string "$failure_category")
  encoded_prior=$(json_string "$prior_phase")
  encoded_resume=$(json_string "$resume_phase")
  canonical=$(printf \
    '["maestro-retry-pause-v1",%s,%s,%s,3,%s,%s]' \
    "$encoded_entity" "$encoded_action" "$encoded_failure" \
    "$encoded_prior" "$encoded_resume")
  digest=$(printf '%s' "$canonical" | sha256sum)
  digest=${digest%% *}
  [[ "$observed_identity" == "retry-pause-v1:$digest" ]]
}

json_string() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\b'/\\b}
  value=${value//$'\f'/\\f}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '"%s"' "$value"
}

emit_validation_timeout_plan() {
  local cleanup_kind=$1 attempts=$2 state_changed=$3 state_observation=$4
  local exhaustion_event=$5 retry_identity=$6
  local resolution_event=$7 resolution_match=$8 disposition=$9
  local resume_phase=${10}
  local pause_identity=${11} resolution_pause_identity=${12}
  local entity_uuid=${13} retry_action_identity=${14}
  local failure_category=${15} prior_phase=${16}
  local pause_resume_phase=${17}
  local reads mutations events suppressed next

  case "$cleanup_kind" in
    attached)
      reads=command-process,review-worktree-reservation,review-action-binding,cleanup-ledger,owned-path,canonical-path,ownership-marker,attachment-state,git-worktree-metadata,directory-contents
      mutations=terminate-command,git-worktree-remove,filesystem-remove-transients
      events=action-failed
      suppressed=review-publication
      next=inconclusive-cleanup-complete
      ;;
    unattached)
      reads=command-process,review-worktree-reservation,review-action-binding,cleanup-ledger,owned-path,canonical-path,ownership-marker,attachment-state,repository-metadata,directory-contents
      mutations=terminate-command,filesystem-remove-reservation
      events=action-failed
      suppressed=review-publication,git-worktree-remove
      next=inconclusive-cleanup-complete
      ;;
    *)
      reads=command-process,review-worktree-reservation,review-action-binding,cleanup-ledger,owned-path,canonical-path,ownership-marker,attachment-state,repository-metadata,directory-contents
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
    elif [[ "$resolution_event" == "recorded" &&
            "$resolution_match" == "exact" &&
            -n "$pause_identity" &&
            "$resolution_pause_identity" == "$pause_identity" &&
            "$disposition" == "resume-after-confirmed-external-state-change" &&
            "$resume_phase" == "confirmed" ]]; then
      reads+=,pause-identity,decision-resolved
      mutations+=,resume-prior-phase,bounded-retry
      suppressed+=,duplicate-retry-exhausted,unbounded-retry
      next+=-retry-after-durable-resolution
    else
      reads+=,pause-identity,decision-resolved
      suppressed+=,resume-prior-phase,bounded-retry,remove-needs-human,duplicate-retry-exhausted,unbounded-retry
      if [[ "$resolution_event" == "recorded" ]]; then
        next+=-needs-human-stale-resolution
      else
        next+=-needs-human-await-matching-resolution
      fi
    fi
  elif [[ "$attempts" == "exhausted" ]]; then
    reads+=,action-journal,relevant-state
    if [[ "$state_changed" == "false" &&
          "$exhaustion_event" == "absent" ]]; then
      reads+=,pause-identity-inputs
      if retry_pause_identity_is_canonical \
          "$entity_uuid" "$retry_action_identity" "$failure_category" \
          "$prior_phase" "$pause_resume_phase" "$pause_identity"; then
        suppressed+=,further-mutation
        next+=-needs-human
        mutations+=,apply-needs-human
        events+=,retry-exhausted
      else
        suppressed+=,apply-needs-human,retry-exhausted,further-mutation
        next+=-pause-identity-invalid
      fi
    else
      suppressed+=,further-mutation
      next+=-needs-human
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

  if [[ "${predicate[surface]:-}" == "review-preparation" &&
        "${predicate[preparation]:-}" == "current" &&
        "${predicate[reservation]:-}" == "current-confirmed" &&
        "${predicate[worktree]:-}" == "absent" &&
        "${predicate[ownership]:-}" == "reconciler" ]]; then
    emit_action_plan none \
      review-worktree-reservation,cleanup-ledger,repository-identity,expected-head \
      create-owned-worktree none \
      review-source-closure,action-binding,review-requested,review-dispatch,ownership-transfer \
      reservation-worktree-create
  elif [[ "${predicate[surface]:-}" == "review-preparation" &&
          "${predicate[preparation]:-}" == "current" &&
          "${predicate[reservation]:-}" == "current-confirmed" &&
          "${predicate[worktree]:-}" == "attached" &&
          "${predicate[worktree_verification]:-}" == "exact" &&
          "${predicate[closure]:-}" == "absent" &&
          "${predicate[marker]:-}" == "reservation-only" &&
          "${predicate[ownership]:-}" == "reconciler" ]]; then
    emit_action_plan none \
      review-worktree-reservation,cleanup-ledger,ownership-marker,repository-identity,expected-head,git-worktree-metadata \
      derive-review-source-closure none \
      action-binding,review-requested,review-dispatch,ownership-transfer \
      reservation-source-closure
  elif [[ "${predicate[surface]:-}" == "review-preparation" &&
          "${predicate[preparation]:-}" == "current" &&
          "${predicate[reservation]:-}" == "current-confirmed" &&
          "${predicate[worktree]:-}" == "attached" &&
          "${predicate[worktree_verification]:-}" == "exact" &&
          "${predicate[closure]:-}" == "derived-current" &&
          "${predicate[action_binding]:-}" == "absent" &&
          "${predicate[journal_binding]:-}" == "absent" &&
          "${predicate[marker]:-}" == "reservation-only" &&
          "${predicate[ownership]:-}" == "reconciler" ]]; then
    emit_action_plan none \
      review-worktree-reservation,review-source-closure,review-input,review-action-identity,ownership-marker \
      append-confirm-review-worktree-action-binding review-worktree-action-bound \
      update-marker,review-requested,review-dispatch,ownership-transfer \
      reservation-action-binding-append
  elif [[ "${predicate[surface]:-}" == "review-preparation" &&
          "${predicate[preparation]:-}" == "current" &&
          "${predicate[reservation]:-}" == "current-confirmed" &&
          "${predicate[worktree]:-}" == "attached" &&
          "${predicate[worktree_verification]:-}" == "exact" &&
          "${predicate[closure]:-}" == "derived-current" &&
          "${predicate[action_binding]:-}" == "confirmed-one-to-one" &&
          "${predicate[journal_binding]:-}" == "match" &&
          "${predicate[marker]:-}" == "reservation-only" &&
          "${predicate[ownership]:-}" == "reconciler" ]]; then
    emit_action_plan none \
      review-worktree-reservation,review-source-closure,review-action-binding,ownership-marker \
      update-marker-bound-action none \
      review-requested,review-dispatch,ownership-transfer \
      reservation-marker-update
  elif [[ "${predicate[surface]:-}" == "review-preparation" &&
          "${predicate[preparation]:-}" == "current" &&
          "${predicate[reservation]:-}" == "current-confirmed" &&
          "${predicate[worktree]:-}" == "attached" &&
          "${predicate[worktree_verification]:-}" == "exact" &&
          "${predicate[closure]:-}" == "derived-current" &&
          "${predicate[action_binding]:-}" == "absent" &&
          "${predicate[journal_binding]:-}" == "absent" &&
          "${predicate[marker]:-}" == "bound-action" &&
          "${predicate[ownership]:-}" == "reconciler" ]]; then
    emit_action_plan mutation-ambiguous \
      review-worktree-reservation,review-source-closure,review-action-binding,ownership-marker \
      none action-failed,cleanup-failed \
      review-requested,review-dispatch,ownership-transfer,filesystem-delete,git-worktree-remove \
      reservation-binding-mismatch-cleanup-debt
  elif [[ "${predicate[surface]:-}" == "review-preparation" &&
          "${predicate[preparation]:-}" == "current" &&
          "${predicate[reservation]:-}" == "current-confirmed" &&
          "${predicate[worktree]:-}" == "attached" &&
          "${predicate[worktree_verification]:-}" == "exact" &&
          "${predicate[closure]:-}" == "derived-current" &&
          "${predicate[action_binding]:-}" == "confirmed-one-to-one" &&
          "${predicate[journal_binding]:-}" == "match" &&
          "${predicate[marker]:-}" == "bound-match" &&
          "${predicate[request_event]:-}" == "absent" &&
          "${predicate[ownership]:-}" == "reconciler" ]]; then
    emit_action_plan none \
      review-preparation,review-worktree-reservation,review-source-closure,review-action-binding,ownership-marker \
      none review-requested \
      review-dispatch,ownership-transfer \
      await-review-request-record
  elif [[ "${predicate[surface]:-}" == "review-preparation" &&
          "${predicate[preparation]:-}" == "current" &&
          "${predicate[reservation]:-}" == "current-confirmed" &&
          "${predicate[worktree]:-}" == "attached" &&
          "${predicate[worktree_verification]:-}" == "exact" &&
          "${predicate[closure]:-}" == "derived-current" &&
          "${predicate[action_binding]:-}" == "confirmed-one-to-one" &&
          "${predicate[journal_binding]:-}" == "match" &&
          "${predicate[marker]:-}" == "bound-match" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[dispatch]:-}" == "absent" &&
          "${predicate[ownership]:-}" == "reconciler" ]]; then
    emit_action_plan none \
      review-worktree-reservation,review-action-binding,ownership-marker,review-requested \
      dispatch-review none \
      ownership-transfer,duplicate-dispatch review-dispatch-eligible
  elif [[ "${predicate[surface]:-}" == "review-preparation" &&
          "${predicate[preparation]:-}" == "current" &&
          "${predicate[reservation]:-}" == "current-confirmed" &&
          "${predicate[worktree]:-}" == "attached" &&
          "${predicate[worktree_verification]:-}" == "exact" &&
          "${predicate[closure]:-}" == "derived-current" &&
          "${predicate[action_binding]:-}" == "confirmed-one-to-one" &&
          "${predicate[journal_binding]:-}" == "match" &&
          "${predicate[marker]:-}" == "bound-match" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[dispatch]:-}" == "failed" &&
          "${predicate[ownership]:-}" == "reconciler" ]]; then
    emit_action_plan tool-failed \
      review-worktree-reservation,review-action-binding,ownership-marker,review-requested,review-dispatch \
      cleanup-owned-worktree action-failed \
      review-dispatch,review-publication,ownership-transfer \
      review-dispatch-failure-cleaned
  elif [[ "${predicate[surface]:-}" == "review-preparation" &&
          "${predicate[preparation]:-}" == "current" &&
          "${predicate[reservation]:-}" == "current-confirmed" &&
          "${predicate[worktree]:-}" == "attached" &&
          "${predicate[worktree_verification]:-}" == "exact" &&
          "${predicate[closure]:-}" == "derived-current" &&
          "${predicate[action_binding]:-}" == "confirmed-one-to-one" &&
          "${predicate[journal_binding]:-}" == "match" &&
          "${predicate[marker]:-}" == "bound-match" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[dispatch]:-}" == "confirmed" &&
          "${predicate[ownership]:-}" == "reconciler" ]]; then
    emit_action_plan none \
      review-worktree-reservation,review-action-binding,ownership-marker,review-requested,review-dispatch \
      transfer-review-worktree-ownership none \
      reconciliation-cleanup,duplicate-dispatch review-dispatched
  elif [[ "${predicate[surface]:-}" == "review-preparation" &&
          "${predicate[preparation]:-}" == "current" &&
          "${predicate[reservation]:-}" == "current-confirmed" &&
          "${predicate[action_binding]:-}" == "conflicting-second-action" ]]; then
    emit_action_plan mutation-ambiguous \
      review-preparation,review-worktree-reservation,review-action-binding,action-journal \
      none action-failed \
      all-review-mutation \
      reservation-one-to-one-conflict
  elif [[ "${predicate[surface]:-}" == "review-publication" &&
          "${predicate[interval]:-}" == "after-github" &&
          "${predicate[github_record]:-}" == "confirmed" &&
          "${predicate[fresh_derivation]:-}" == "confirmed" &&
          "${predicate[reviewed_input]:-}" != "${predicate[fresh_input]:-}" &&
          "${predicate[worktree]:-}" == "owned" ]]; then
    emit_action_plan review-input-stale \
      confirmed-github-record,fresh-review-context,evidence-template-bindings,acceptance-evidence-manifest,review-source-closure,capability-state,decision-resolutions,review-input \
      cleanup-owned-worktree review-input-stale \
      linear-cursor-follow-up,github-record-satisfies-current,review-recorded,merge-ready \
      new-review-input-eligible-github-record-historical
  elif [[ "${predicate[surface]:-}" == "review-publication" &&
          "${predicate[interval]:-}" == "after-github" &&
          "${predicate[github_record]:-}" == "confirmed" &&
          "${predicate[fresh_derivation]:-}" == "failed" &&
          "${predicate[worktree]:-}" == "owned" ]]; then
    emit_action_plan review-input-stale \
      confirmed-github-record,fresh-review-context,evidence-template-bindings,acceptance-evidence-manifest,review-source-closure,capability-state,decision-resolutions,review-input \
      cleanup-owned-worktree review-input-stale \
      linear-cursor-follow-up,github-record-satisfies-current,review-recorded,merge-ready \
      review-input-derivation-recovery-github-record-historical
  elif [[ "${predicate[surface]:-}" == "review-publication" &&
          "${predicate[interval]:-}" == "after-github" &&
          "${predicate[github_record]:-}" == "confirmed" &&
          "${predicate[fresh_derivation]:-}" == "confirmed" &&
          "${predicate[reviewed_input]:-}" == "${predicate[fresh_input]:-}" &&
          "${predicate[linear_record]:-}" == "absent" &&
          "${predicate[worktree]:-}" == "owned" ]]; then
    emit_action_plan none \
      confirmed-github-record,fresh-review-context,evidence-template-bindings,acceptance-evidence-manifest,review-source-closure,capability-state,decision-resolutions,review-input,linear-publication-identity \
      publish-or-recover-linear-follow-up review-recorded \
      duplicate-linear-follow-up current-review-publication-complete
  elif [[ "${predicate[surface]:-}" == "review-publication" &&
          "${predicate[interval]:-}" == "before-github" &&
          "${predicate[review_requested]:-}" == "confirmed" &&
          "${predicate[fresh_derivation]:-}" == "confirmed" &&
        "${predicate[reviewed_input]:-}" != "${predicate[fresh_input]:-}" &&
        "${predicate[worktree]:-}" == "owned" ]]; then
    emit_action_plan review-input-stale \
      fresh-review-context,evidence-template-bindings,acceptance-evidence-manifest,review-source-closure,capability-state,decision-resolutions,review-input \
      cleanup-owned-worktree review-input-stale \
      github-review-publication,linear-cursor-follow-up,review-recorded,merge-ready \
      new-review-input-eligible
  elif [[ "${predicate[surface]:-}" == "review-publication" &&
          "${predicate[interval]:-}" == "before-github" &&
          "${predicate[review_requested]:-}" == "confirmed" &&
          "${predicate[fresh_derivation]:-}" == "failed" &&
          "${predicate[worktree]:-}" == "owned" ]]; then
    emit_action_plan review-input-underivable \
      fresh-review-context,evidence-template-bindings,acceptance-evidence-manifest,review-source-closure,capability-state,decision-resolutions,review-input \
      cleanup-owned-worktree action-failed \
      github-review-publication,linear-cursor-follow-up,review-recorded,merge-ready,new-review-input-eligible \
      review-input-derivation-recovery
  elif [[ "${predicate[surface]:-}" == "review-binding" &&
          "${predicate[binding_state]:-}" == "unresolved" ]]; then
    emit_action_plan observation-incomplete \
      evidence-requirements,fresh-native-state,runtime-bindings \
      cleanup-owned-worktree action-failed \
      review-requested,review-publication,review-recorded,merge-ready \
      evidence-binding-recovery
  elif [[ "${predicate[surface]:-}" == "review-binding" &&
          "${predicate[binding_state]:-}" == "ambiguous" ]]; then
    emit_action_plan mutation-ambiguous \
      evidence-requirements,fresh-native-state,runtime-bindings \
      cleanup-owned-worktree action-failed \
      review-requested,review-publication,review-recorded,merge-ready \
      evidence-binding-recovery
  elif [[ "${predicate[surface]:-}" == "review" &&
        "${predicate[missing_evidence]:-}" == "unkeyed" &&
        "${predicate[acceptance_manifest]:-}" == "incomplete" ]]; then
    emit_action_plan observation-incomplete \
      current-review-input,acceptance-evidence-manifest,review-publication \
      none action-failed \
      review-publication,review-recorded,merge-ready \
      unkeyed-evidence-bounded-recovery
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[verdict]:-}" == "inconclusive" &&
          "${predicate[missing_evidence]:-}" == "actionable" &&
          "${predicate[acceptance_manifest]:-}" != "complete-keyed" ]]; then
    emit_action_plan observation-incomplete \
      current-review-input,acceptance-evidence-manifest,review-publication \
      none action-failed \
      review-publication,review-recorded,merge-ready \
      unkeyed-evidence-bounded-recovery
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "absent" &&
          "${predicate[verdict]:-}" == "inconclusive" &&
          "${predicate[publication]:-}" == "confirmed" &&
          "${predicate[missing_evidence]:-}" == "actionable" &&
          "${predicate[acceptance_manifest]:-}" == "complete-keyed" ]]; then
    emit_action_plan none \
      current-review-input,review-requested,acceptance-evidence-manifest,review-publication \
      none review-recorded merge-ready,duplicate-publication \
      current-revision-inconclusive-recorded
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "absent" &&
          "${predicate[current_result]:-}" == "absent" &&
          ( "${predicate[acceptance_manifest]:-}" == "changed-keyed" ||
            "${predicate[acceptance_manifest]:-}" == "provider-revision-changed" ) ]]; then
    emit_action_plan none \
      fresh-provider-evidence,acceptance-evidence-manifest,review-source-closure,decision-resolutions,review-requested,current-review-result \
      none none \
      review-dispatch,prior-review-satisfies-current,prior-review-blocks-current,merge-ready \
      await-authoritative-review-preparation
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "absent" &&
          "${predicate[acceptance_manifest]:-}" == "changed-keyed" &&
          -z "${predicate[verdict]:-}" ]]; then
    emit_action_plan none \
      fresh-provider-evidence,acceptance-evidence-manifest,review-source-closure,decision-resolutions,review-requested,current-review-result \
      none none \
      review-dispatch,prior-review-satisfies-current,prior-review-blocks-current,merge-ready \
      await-authoritative-review-preparation
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "absent" &&
          "${predicate[acceptance_manifest]:-}" == "changed-keyed" &&
          "${predicate[verdict]:-}" == "pass" &&
          "${predicate[publication]:-}" == "confirmed" ]]; then
    emit_action_plan none \
      current-review-input,review-requested,acceptance-evidence-manifest,review-publication \
      record-current-review-pass review-recorded \
      older-review-result,duplicate-publication current-review-pass
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "absent" &&
          "${predicate[current_result]:-}" == "absent" ]]; then
    emit_action_plan none \
      fresh-provider-evidence,decision-resolutions,review-requested,current-review-result \
      none none \
      review-dispatch,prior-review-satisfies-current,prior-review-blocks-current,merge-ready \
      await-authoritative-review-preparation
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "pass-recorded" &&
          "${predicate[publication]:-}" == "confirmed" ]]; then
    emit_action_plan none \
      current-review-input,review-requested,current-review-result \
      none none review-dispatch,duplicate-publication current-review-pass
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "inconclusive-recorded" &&
          "${predicate[publication]:-}" == "confirmed" ]]; then
    emit_action_plan none \
      current-review-input,review-requested,current-review-result \
      none none review-dispatch,duplicate-publication,merge-ready \
      await-changed-evidence-or-input-revision
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "human-decision-recorded" ]]; then
    if [[ "${predicate[resolution_event]:-}" == "recorded" &&
          "${predicate[resolution_match]:-}" == "stale" ]]; then
      emit_action_plan none \
        current-review-input,review-requested,current-review-result,decision-resolved \
        none none review-dispatch,remove-pause-label,merge-ready \
        human-decision-paused-stale-resolution
    else
      emit_action_plan none \
        current-review-input,review-requested,current-review-result,decision-resolved \
        none none review-dispatch,remove-pause-label,merge-ready \
        human-decision-paused
    fi
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "changes-required-recorded" &&
          "${predicate[inputs_changed]:-}" == "false" ]]; then
    emit_action_plan none \
      current-review-input,review-requested,current-review-result \
      none none review-dispatch,duplicate-publication,merge-ready \
      await-new-head-contract-policy-or-input-revision
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "absent" &&
          "${predicate[verdict]:-}" == "pass" &&
          "${predicate[publication]:-}" == "confirmed" ]]; then
    emit_action_plan none \
      current-review-input,review-requested,review-publication \
      record-current-review-pass review-recorded \
      older-review-result,duplicate-publication current-review-pass
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "absent" &&
          "${predicate[verdict]:-}" == "inconclusive" &&
          "${predicate[publication]:-}" == "unpublished" ]]; then
    emit_action_plan observation-incomplete \
      current-review-input,review-requested,review-publication \
      none action-failed review-recorded,merge-ready \
      inconclusive-bounded-retry
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "absent" &&
          "${predicate[prior_result]:-}" == "human-decision" &&
          "${predicate[resolution_event]:-}" == "recorded" &&
          "${predicate[resolution_match]:-}" != "exact" ]]; then
    emit_action_plan none \
      fresh-provider-evidence,decision-resolutions,review-requested,current-review-result \
      none none \
      review-dispatch,prior-review-satisfies-current,remove-pause-label,merge-ready \
      human-decision-paused-stale-resolution
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "absent" &&
          "${predicate[prior_result]:-}" == "pass" ]]; then
    emit_action_plan none \
      current-review-input,review-requested,current-review-result \
      none none review-dispatch,prior-review-satisfies-current,merge-ready \
      await-authoritative-review-preparation
  elif [[ "${predicate[surface]:-}" == "review" &&
          "${predicate[head]:-}" == "same" &&
          "${predicate[request_event]:-}" == "recorded" &&
          "${predicate[current_result]:-}" == "absent" ]]; then
    emit_action_plan none \
      fresh-provider-evidence,decision-resolutions,review-requested,current-review-result \
      none none \
      review-dispatch,prior-review-satisfies-current,prior-review-blocks-current,merge-ready \
      await-authoritative-review-preparation
  elif [[ "${predicate[surface]:-}" == "pause-restoration" &&
          "${predicate[fresh_session]:-}" == "true" &&
          "${predicate[pause_event]:-}" == "recorded" &&
          "${predicate[pause_class]:-}" == "strategic" &&
          "${predicate[native_label]:-}" == "missing" &&
          "${predicate[resolution_event]:-}" == "absent" ]]; then
    emit_action_plan none \
      pause-event,pause-classification,native-labels,decision-resolved \
      apply-scope-change none \
      apply-needs-human,remove-pause-label,resume-phase,downstream-unlock \
      strategic-pause-restored
  elif [[ "${predicate[surface]:-}" == "pause-restoration" &&
          "${predicate[fresh_session]:-}" == "true" &&
          "${predicate[pause_event]:-}" == "recorded" &&
          "${predicate[pause_class]:-}" == "bounded" &&
          "${predicate[native_label]:-}" == "missing" &&
          "${predicate[resolution_event]:-}" == "absent" ]]; then
    emit_action_plan none \
      pause-event,pause-classification,native-labels,decision-resolved \
      apply-needs-human none \
      apply-scope-change,remove-pause-label,resume-phase,downstream-unlock \
      bounded-pause-restored
  elif [[ "${predicate[surface]:-}" == "validation" &&
        "${predicate[command]:-}" == "timed-out" ]]; then
    if [[ "${predicate[owned_path]:-}" == "known" &&
          "${predicate[binding]:-}" == "absent" ]] &&
       reservation_attached_cleanup_is_safe \
         "${predicate[containment]:-}" "${predicate[reservation]:-}" \
         "${predicate[ledger]:-}" "${predicate[marker]:-}" \
         "${predicate[attachment]:-}" "${predicate[git_metadata]:-}" \
         "${predicate[contents]:-}"; then
      cleanup_kind=attached
    elif [[ "${predicate[owned_path]:-}" == "known" &&
            "${predicate[binding]:-}" == "absent" ]] &&
         reservation_unattached_cleanup_is_safe \
           "${predicate[containment]:-}" "${predicate[reservation]:-}" \
           "${predicate[ledger]:-}" "${predicate[marker]:-}" \
           "${predicate[attachment]:-}" \
           "${predicate[git_metadata]:-}" "${predicate[checkout]:-}" \
           "${predicate[contents]:-}"; then
      cleanup_kind=unattached
    elif [[ "${predicate[owned_path]:-}" == "known" &&
            "${predicate[binding]:-}" == "confirmed-one-to-one" ]] &&
         bound_review_attached_cleanup_is_safe \
           "${predicate[containment]:-}" "${predicate[reservation]:-}" \
           "${predicate[ledger]:-}" "${predicate[marker]:-}" \
           "${predicate[bound_action]:-}" "${predicate[attachment]:-}" \
           "${predicate[git_metadata]:-}" "${predicate[contents]:-}"; then
      cleanup_kind=attached
    elif [[ "${predicate[owned_path]:-}" == "known" &&
            "${predicate[binding]:-}" == "confirmed-one-to-one" ]] &&
         bound_review_unattached_cleanup_is_safe \
           "${predicate[containment]:-}" "${predicate[reservation]:-}" \
           "${predicate[ledger]:-}" "${predicate[marker]:-}" \
           "${predicate[bound_action]:-}" "${predicate[attachment]:-}" \
           "${predicate[git_metadata]:-}" "${predicate[checkout]:-}" \
           "${predicate[contents]:-}"; then
      cleanup_kind=unattached
    else
      cleanup_kind=unsafe
    fi
    emit_validation_timeout_plan "$cleanup_kind" \
      "${predicate[attempts]:-}" "${predicate[state_changed]:-}" \
      "${predicate[state_change_observation]:-}" \
      "${predicate[exhaustion_event]:-}" "${predicate[retry_identity]:-}" \
      "${predicate[resolution_event]:-}" "${predicate[resolution_match]:-}" \
      "${predicate[disposition]:-}" "${predicate[resume_phase]:-}" \
      "${predicate[pause_identity]:-}" \
      "${predicate[resolution_pause_identity]:-}" \
      "${predicate[entity_uuid]:-}" \
      "${predicate[retry_action_identity]:-}" \
      "${predicate[failure_category]:-}" \
      "${predicate[prior_phase]:-}" \
      "${predicate[pause_resume_phase]:-}"
  elif [[ "${predicate[attempts]:-}" == "exhausted" &&
        "${predicate[state_changed]:-}" == "true" &&
        "${predicate[state_change_observation]:-}" == "confirmed" &&
        "${predicate[exhaustion_event]:-}" == "recorded" &&
        "${predicate[action_identity]:-}" == "stable" &&
        "${predicate[resolution_event]:-}" == "recorded" &&
        "${predicate[resolution_match]:-}" == "exact" &&
        -n "${predicate[pause_identity]:-}" &&
        "${predicate[resolution_pause_identity]:-}" == \
          "${predicate[pause_identity]:-}" &&
        "${predicate[disposition]:-}" == \
          "resume-after-confirmed-external-state-change" &&
        "${predicate[resume_phase]:-}" == "confirmed" ]]; then
    emit_action_plan "${predicate[failure]:-permanent-invalid}" \
      action-journal,fresh-native-state,relevant-state,stable-action-identity,pause-identity,decision-resolved \
      resume-prior-phase,bounded-retry none \
      duplicate-retry-exhausted,unbounded-retry \
      retry-after-durable-resolution
  elif [[ "${predicate[attempts]:-}" == "exhausted" &&
        "${predicate[state_changed]:-}" == "true" &&
        "${predicate[state_change_observation]:-}" == "confirmed" &&
        "${predicate[exhaustion_event]:-}" == "recorded" &&
        "${predicate[action_identity]:-}" == "stable" ]]; then
    if [[ "${predicate[resolution_event]:-}" == "recorded" ]]; then
      emit_action_plan "${predicate[failure]:-permanent-invalid}" \
        action-journal,fresh-native-state,relevant-state,stable-action-identity,pause-identity,decision-resolved \
        none none \
        resume-prior-phase,bounded-retry,remove-needs-human,duplicate-retry-exhausted,unbounded-retry \
        needs-human-stale-resolution
    else
      emit_action_plan "${predicate[failure]:-permanent-invalid}" \
        action-journal,fresh-native-state,relevant-state,stable-action-identity,pause-identity,decision-resolved \
        none none \
        resume-prior-phase,bounded-retry,remove-needs-human,duplicate-retry-exhausted,unbounded-retry \
        needs-human-await-matching-resolution
    fi
  elif [[ "${predicate[attempts]:-}" == "exhausted" &&
        "${predicate[state_changed]:-}" == "false" &&
        "${predicate[exhaustion_event]:-}" == "absent" ]]; then
    if retry_pause_identity_is_canonical \
        "${predicate[entity_uuid]:-}" "${predicate[action_identity]:-}" \
        "${predicate[failure]:-}" "${predicate[prior_phase]:-}" \
        "${predicate[resume_phase]:-}" "${predicate[pause_identity]:-}"; then
      emit_action_plan "${predicate[failure]:-permanent-invalid}" \
        action-journal,relevant-state,pause-identity-inputs \
        apply-needs-human retry-exhausted further-mutation needs-human
    else
      emit_action_plan "${predicate[failure]:-permanent-invalid}" \
        action-journal,relevant-state,pause-identity-inputs none none \
        apply-needs-human,retry-exhausted,further-mutation \
        pause-identity-invalid
    fi
  elif [[ "${predicate[attempts]:-}" == "exhausted" ]]; then
    emit_action_plan "${predicate[failure]:-permanent-invalid}" \
      action-journal,relevant-state none none further-mutation needs-human
  elif [[ "${predicate[surface]:-}" == "status" &&
          "${predicate[exhaustion_event]:-}" == "recorded" &&
          "${predicate[resolution_event]:-}" == "recorded" &&
          "${predicate[resolution_match]:-}" == "exact" &&
          -n "${predicate[pause_identity]:-}" &&
          "${predicate[resolution_pause_identity]:-}" == \
            "${predicate[pause_identity]:-}" &&
          "${predicate[disposition]:-}" == \
            "resume-after-confirmed-external-state-change" &&
          "${predicate[resume_phase]:-}" == "confirmed" ]]; then
    emit_action_plan none retry-exhausted,decision-resolved,native-phase \
      none none none resolved-historical-exhaustion-closeout-clear
  elif [[ "${predicate[surface]:-}" == "status" &&
          "${predicate[exhaustion_event]:-}" == "recorded" ]]; then
    emit_action_plan none retry-exhausted,decision-resolved,native-phase \
      none none closeout unresolved-exhaustion-closeout-blocked
  elif [[ "${predicate[surface]:-}" == "identity" &&
          "${predicate[fresh_session]:-}" == "reproduced" &&
          "${predicate[create_outcome]:-}" == "ambiguous" &&
          "${predicate[identity_matches]:-}" == "one" ]]; then
    emit_action_plan none \
      "durable-${predicate[family]:-unknown}-inputs,canonical-identity,exact-native-scope" \
      none none repeat-create recovered-canonical-record
  elif [[ "${predicate[surface]:-}" == "identity" &&
          "${predicate[fresh_session]:-}" == "reproduced" &&
          "${predicate[create_outcome]:-}" == "ambiguous" &&
          "${predicate[identity_matches]:-}" == "multiple" ]]; then
    emit_action_plan mutation-ambiguous \
      "durable-${predicate[family]:-unknown}-inputs,canonical-identity,exact-native-scope" \
      none action-failed create,retry needs-human-ambiguous-identity
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
  elif [[ "${predicate[surface]:-}" == "linear" &&
          "${predicate[record_family]:-}" == "discovery-issue" &&
          "${predicate[create_outcome]:-}" == "ambiguous" &&
          "${predicate[action_identity]:-}" == "stable" ]]; then
    emit_action_plan mutation-ambiguous discovery-action-identity-search none \
      action-failed repeat-create,dependent-mutation resolve-discovery-issue
  elif [[ "${predicate[surface]:-}" == "linear" &&
          "${predicate[record_family]:-}" == "required-follow-up" &&
          "${predicate[create_outcome]:-}" == "ambiguous" &&
          "${predicate[action_identity]:-}" == "stable" ]]; then
    emit_action_plan mutation-ambiguous follow-up-action-identity-search none \
      action-failed repeat-create,closeout resolve-required-follow-up
  elif [[ "${predicate[surface]:-}" == "github" &&
          "${predicate[record_family]:-}" == "github-review-record" &&
          "${predicate[create_outcome]:-}" == "ambiguous" &&
          "${predicate[action_identity]:-}" == "stable" &&
          "${predicate[pr_head]:-}" == "exact" ]]; then
    emit_action_plan mutation-ambiguous \
      github-review-action-identity-search none action-failed \
      repeat-publication,linear-cursor-follow-up \
      resolve-canonical-github-record
  elif [[ "${predicate[surface]:-}" == "linear" &&
          "${predicate[record_family]:-}" == "linear-cursor-follow-up" &&
          "${predicate[create_outcome]:-}" == "ambiguous" &&
          "${predicate[action_identity]:-}" == "stable" &&
          "${predicate[github_record]:-}" == "confirmed" ]]; then
    emit_action_plan mutation-ambiguous \
      linear-cursor-follow-up-identity-search none action-failed \
      repeat-create,duplicate-follow-up resolve-linear-cursor-follow-up
  elif [[ "${predicate[surface]:-}" == "github" &&
          "${predicate[publication]:-}" == "pending" &&
          ( "${predicate[pr_head]:-}" == "stale" ||
            "${predicate[preparation]:-}" == "stale" ) &&
          "${predicate[review_requested]:-}" == "absent" ]]; then
    emit_action_plan review-stale-head github-pr-head,linear-contract-dag,review-preparation \
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
          "${predicate[proposal]:-}" == "recorded" &&
          "${predicate[approval]:-}" == "rejected" &&
          "${predicate[rejection_event]:-}" == "absent" ]]; then
    emit_action_plan none \
      dag-proposed,rejection-evidence,proposal-action-identity none \
      dag-rejected dag-approval,dag-materialization \
      replan-after-durable-rejection
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[proposal]:-}" == "recorded" &&
          "${predicate[approval]:-}" == "rejected" &&
          "${predicate[rejection_event]:-}" == "recorded" ]]; then
    emit_action_plan none dag-proposed,dag-rejected none none \
      dag-approval,dag-materialization rejected-revision-historical
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[approval]:-}" == "recorded" &&
          "${predicate[node]:-}" == "missing" ]]; then
    emit_action_plan none \
      dag-approved,dag-node-bound,native-node-identity \
      linear-create-missing-node none \
      linear-create-missing-edge,dag-node-bound,dag-edge-bound,dag-materialized \
      await-node-confirmation
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[approval]:-}" == "recorded" &&
          "${predicate[node]:-}" == "create-ambiguous" ]]; then
    emit_action_plan mutation-ambiguous \
      dag-approved,node-action-identity-search none action-failed \
      linear-create-missing-node,linear-create-missing-edge,dag-node-bound,dag-edge-bound,dag-materialized \
      resolve-node-identity
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[approval]:-}" == "recorded" &&
          "${predicate[node]:-}" == "confirmed" &&
          "${predicate[node_binding]:-}" == "missing" ]]; then
    emit_action_plan none \
      dag-approved,native-node,stable-node-action-identity none dag-node-bound \
      linear-create-missing-node,linear-create-missing-edge,dag-edge-bound,dag-materialized \
      await-node-binding-event
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[approval]:-}" == "recorded" &&
          "${predicate[nodes]:-}" == "bound" &&
          "${predicate[edge]:-}" == "missing" ]]; then
    emit_action_plan none \
      dag-approved,dag-node-bound,dag-edge-bound,native-node-bindings,native-edge-identity \
      linear-create-missing-edge none \
      linear-create-missing-node,dag-node-bound,dag-edge-bound,dag-materialized \
      await-edge-confirmation
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[approval]:-}" == "recorded" &&
          "${predicate[nodes]:-}" == "bound" &&
          "${predicate[edge]:-}" == "create-ambiguous" ]]; then
    emit_action_plan mutation-ambiguous \
      dag-approved,dag-node-bound,native-edge-resolution none action-failed \
      linear-create-missing-node,linear-create-missing-edge,dag-node-bound,dag-edge-bound,dag-materialized \
      resolve-native-edge
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[approval]:-}" == "recorded" &&
          "${predicate[nodes]:-}" == "bound" &&
          "${predicate[edge]:-}" == "confirmed" &&
          "${predicate[edge_binding]:-}" == "missing" ]]; then
    emit_action_plan none \
      dag-approved,dag-node-bound,native-edge,stable-edge-action-identity \
      none dag-edge-bound \
      linear-create-missing-node,linear-create-missing-edge,dag-node-bound,dag-materialized \
      await-edge-binding-event
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[approval]:-}" == "recorded" &&
          "${predicate[nodes]:-}" == "bound" &&
          "${predicate[edges]:-}" == "bound" &&
          "${predicate[materialization]:-}" == "missing" ]]; then
    emit_action_plan none \
      dag-approved,dag-node-bound,dag-edge-bound,native-bindings \
      none dag-materialized \
      linear-create-missing-node,linear-create-missing-edge,dag-node-bound,dag-edge-bound \
      await-materialization-event
  elif [[ "${predicate[surface]:-}" == "dag" &&
          "${predicate[approval]:-}" == "recorded" &&
          "${predicate[nodes]:-}" == "bound" &&
          "${predicate[edges]:-}" == "bound" &&
          "${predicate[materialization]:-}" == "recorded" ]]; then
    emit_action_plan none \
      dag-approved,dag-node-bound,dag-edge-bound,dag-materialized,native-bindings \
      none none \
      linear-create-missing-node,linear-create-missing-edge,dag-node-bound,dag-edge-bound,duplicate-dag-materialized \
      materialized
  elif [[ "${predicate[surface]:-}" == "pause" &&
          "${predicate[pause_event]:-}" == "recorded" &&
          "${predicate[resolution_event]:-}" == "absent" &&
          "${predicate[disposition]:-}" == "absent" ]]; then
    emit_action_plan none \
      human-decision-required,semantic-drift-detected,native-phase none none \
      remove-needs-human,remove-scope-change,resume-phase unresolved-pause
  elif [[ "${predicate[surface]:-}" == "pause" &&
          "${predicate[pause_event]:-}" == "recorded" &&
          "${predicate[resolution_event]:-}" == "absent" &&
          ( "${predicate[disposition]:-}" == "restore-approved-state" ||
            "${predicate[disposition]:-}" == "accept-observed-as-revision" ||
            "${predicate[disposition]:-}" == "revise-affected-wave" ) &&
          "${predicate[approval_evidence]:-}" == "confirmed" &&
          "${predicate[resume_phase]:-}" == "confirmed" ]]; then
    emit_action_plan none \
      pause-action-identity,governing-revision,affected-subgraph,approval-evidence,resume-phase \
      none decision-resolved \
      remove-needs-human,remove-scope-change,resume-phase \
      await-resolution-event
  elif [[ "${predicate[surface]:-}" == "pause" &&
          "${predicate[pause_event]:-}" == "recorded" &&
          "${predicate[resolution_event]:-}" == "recorded" &&
          ( "${predicate[disposition]:-}" == "restore-approved-state" ||
            "${predicate[disposition]:-}" == "accept-observed-as-revision" ||
            "${predicate[disposition]:-}" == "revise-affected-wave" ) &&
          "${predicate[approval_evidence]:-}" == "confirmed" &&
          "${predicate[resume_phase]:-}" == "confirmed" ]]; then
    emit_action_plan none decision-resolved,native-phase,affected-subgraph \
      remove-pause-label,resume-recorded-phase none \
      duplicate-decision-resolved resumed-recorded-phase
  elif [[ "${predicate[surface]:-}" == "merge-reconciliation" &&
          "${predicate[merge]:-}" == "observed" &&
          "${predicate[binding_manifest]:-}" == "exact-current" &&
          "${predicate[manifest_recompute]:-}" == "exact-current-match" &&
          "${predicate[reconciler_result]:-}" == "validated-same-identity" &&
          "${predicate[reconciler_echo]:-}" == "complete-exact" &&
          "${predicate[conclusion_mapping]:-}" == "exact" &&
          "${predicate[reconciliation_identity]:-}" == "current-match" &&
          "${predicate[acceptance]:-}" == "satisfied" &&
          "${predicate[verdict]:-}" == "complete" &&
          "${predicate[merge_reconciled]:-}" == "absent" ]]; then
    emit_action_plan none \
      merge-observation,reconciliation-binding-manifest,reconciler-result-identity,acceptance-evidence,reconciliation-action-identity \
      persist-merge-reconciliation merge-reconciled \
      duplicate-merge-observed,implementation-completion,downstream-unlock,symphony-closeout \
      merge-reconciled-confirmed
  elif [[ "${predicate[surface]:-}" == "merge-reconciliation" &&
          "${predicate[merge]:-}" == "observed" &&
          "${predicate[binding_manifest]:-}" == "exact-current" &&
          "${predicate[manifest_recompute]:-}" == "exact-current-match" &&
          "${predicate[reconciliation_identity]:-}" == "current-match" &&
          "${predicate[merge_reconciled]:-}" == "recorded" ]]; then
    emit_action_plan none merge-observation,merge-reconciled none none \
      duplicate-merge-observed,duplicate-merge-reconciled,reconciliation \
      merge-reconciled-confirmed
  elif [[ "${predicate[surface]:-}" == "merge-reconciliation" &&
          "${predicate[merge]:-}" == "observed" &&
          ( "${predicate[binding_manifest]:-}" == "unresolved" ||
            "${predicate[binding_manifest]:-}" == "ambiguous" ||
            "${predicate[binding_manifest]:-}" == "missing" ||
            "${predicate[binding_manifest]:-}" == "unavailable" ||
            "${predicate[binding_manifest]:-}" == "omitted" ||
            "${predicate[binding_manifest]:-}" == "stale" ||
            "${predicate[binding_manifest]:-}" == "mismatched" ) ]]; then
    emit_action_plan observation-incomplete \
      merge-observation,reconciliation-requirements,reconciliation-binding-manifest \
      none action-failed \
      merge-reconciled,implementation-completion,downstream-unlock,symphony-closeout \
      postmerge-evidence-recovery
  elif [[ "${predicate[surface]:-}" == "merge-reconciliation" &&
          "${predicate[merge]:-}" == "observed" &&
          "${predicate[verdict]:-}" == "human-decision" &&
          "${predicate[binding_manifest]:-}" == "exact-current" &&
          "${predicate[manifest_recompute]:-}" == "exact-current-match" &&
          "${predicate[reconciler_result]:-}" == "validated-same-identity" &&
          "${predicate[reconciler_echo]:-}" == "complete-exact" &&
          "${predicate[conclusion_mapping]:-}" == "exact" &&
          "${predicate[reconciliation_identity]:-}" == "current-match" ]]; then
    emit_action_plan none \
      merge-observation,reconciliation-binding-manifest,reconciler-result-identity \
      apply-needs-human human-decision-required \
      merge-reconciled,implementation-completion,downstream-unlock,symphony-closeout \
      human-decision
  elif [[ "${predicate[surface]:-}" == "merge-reconciliation" &&
          "${predicate[merge]:-}" == "observed" &&
          "${predicate[verdict]:-}" == "inconclusive" &&
          "${predicate[binding_manifest]:-}" == "exact-current" &&
          "${predicate[manifest_recompute]:-}" == "exact-current-match" &&
          "${predicate[reconciler_result]:-}" == "validated-same-identity" &&
          "${predicate[reconciler_echo]:-}" == "complete-exact" &&
          "${predicate[conclusion_mapping]:-}" == "exact" &&
          "${predicate[reconciliation_identity]:-}" == "current-match" ]]; then
    emit_action_plan observation-incomplete \
      merge-observation,reconciliation-binding-manifest,reconciler-result-identity \
      none action-failed \
      merge-reconciled,implementation-completion,downstream-unlock,symphony-closeout \
      inconclusive-bounded-retry
  elif [[ "${predicate[surface]:-}" == "implementation-completion" &&
          "${predicate[merge_reconciled]:-}" == "confirmed" &&
          "${predicate[completion_event]:-}" == "absent" ]]; then
    emit_action_plan none merge-reconciled,implementation-completion-identity \
      complete-implementation,update-downstream implementation-completed \
      duplicate-implementation-completed,symphony-closeout implementation-complete
  elif [[ "${predicate[surface]:-}" == "implementation-completion" &&
          "${predicate[merge_reconciled]:-}" == "confirmed" &&
          "${predicate[completion_event]:-}" == "recorded" ]]; then
    emit_action_plan none implementation-completed none none \
      duplicate-implementation-completed implementation-complete
  elif [[ "${predicate[surface]:-}" == "symphony-closeout" &&
          "${predicate[integration]:-}" == "confirmed" &&
          "${predicate[required_work]:-}" == "complete-or-approved-cancelled" &&
          "${predicate[merges]:-}" == "reconciled" &&
          "${predicate[active_work]:-}" == "absent" &&
          "${predicate[blockers]:-}" == "absent" &&
          "${predicate[cleanup_debt]:-}" == "absent" &&
          "${predicate[followups]:-}" == "confirmed" &&
          "${predicate[closeout_event]:-}" == "absent" ]]; then
    emit_action_plan none \
      integration-evidence,required-work,merge-reconciliations,active-work,blocking-state,cleanup-ledger,follow-up-identities,closeout-identity \
      finalize-control-outcome,apply-control-complete symphony-completed \
      duplicate-symphony-completed symphony-complete
  elif [[ "${predicate[surface]:-}" == "symphony-closeout" &&
          "${predicate[closeout_event]:-}" == "recorded" ]]; then
    emit_action_plan none symphony-completed none none \
      duplicate-symphony-completed symphony-complete
  elif [[ "${predicate[surface]:-}" == "cleanup" &&
          "${predicate[binding]:-}" == "absent" ]] &&
       reservation_unattached_cleanup_is_safe \
         "${predicate[containment]:-}" "${predicate[reservation]:-}" \
         "${predicate[ledger]:-}" "${predicate[marker]:-}" \
         "${predicate[attachment]:-}" "${predicate[git_metadata]:-}" \
         "${predicate[checkout]:-}" "${predicate[contents]:-}"; then
    emit_action_plan none \
      canonical-path,review-worktree-reservation,cleanup-ledger,ownership-marker,attachment-state,repository-metadata,directory-contents \
      filesystem-remove-reservation none git-worktree-remove cleanup-complete
  elif [[ "${predicate[surface]:-}" == "cleanup" &&
          "${predicate[binding]:-}" == "absent" ]] &&
       reservation_attached_cleanup_is_safe \
         "${predicate[containment]:-}" "${predicate[reservation]:-}" \
         "${predicate[ledger]:-}" "${predicate[marker]:-}" \
         "${predicate[attachment]:-}" "${predicate[git_metadata]:-}" \
         "${predicate[contents]:-}"; then
    emit_action_plan none \
      canonical-path,review-worktree-reservation,cleanup-ledger,ownership-marker,attachment-state,git-worktree-metadata,directory-contents \
      git-worktree-remove,filesystem-remove-transients none none cleanup-complete
  elif [[ "${predicate[surface]:-}" == "cleanup" &&
          "${predicate[binding]:-}" == "confirmed-one-to-one" ]] &&
       bound_review_unattached_cleanup_is_safe \
         "${predicate[containment]:-}" "${predicate[reservation]:-}" \
         "${predicate[ledger]:-}" "${predicate[marker]:-}" \
         "${predicate[bound_action]:-}" "${predicate[attachment]:-}" \
         "${predicate[git_metadata]:-}" "${predicate[checkout]:-}" \
         "${predicate[contents]:-}"; then
    emit_action_plan none \
      canonical-path,review-worktree-reservation,review-action-binding,cleanup-ledger,ownership-marker,attachment-state,repository-metadata,directory-contents \
      filesystem-remove-reservation none git-worktree-remove cleanup-complete
  elif [[ "${predicate[surface]:-}" == "cleanup" &&
          "${predicate[binding]:-}" == "confirmed-one-to-one" ]] &&
       bound_review_attached_cleanup_is_safe \
         "${predicate[containment]:-}" "${predicate[reservation]:-}" \
         "${predicate[ledger]:-}" "${predicate[marker]:-}" \
         "${predicate[bound_action]:-}" "${predicate[attachment]:-}" \
         "${predicate[git_metadata]:-}" "${predicate[contents]:-}"; then
    emit_action_plan none \
      canonical-path,review-worktree-reservation,review-action-binding,cleanup-ledger,ownership-marker,attachment-state,git-worktree-metadata,directory-contents \
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
