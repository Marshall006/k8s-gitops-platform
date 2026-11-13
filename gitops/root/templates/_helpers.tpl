{{/* Politique de synchronisation commune : automatique, avec auto-réparation */}}
{{- define "root.syncPolicy" -}}
syncPolicy:
  automated:
    prune: true     # supprime du cluster ce qui a été supprimé de Git
    selfHeal: true  # annule toute modification manuelle du cluster
  retry:
    limit: 10
    backoff:
      duration: 10s
      factor: 2
      maxDuration: 3m
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
{{- end -}}

{{/* Source « values » : permet aux charts tiers d'utiliser des fichiers de ce dépôt */}}
{{- define "root.valuesSource" -}}
- repoURL: {{ .Values.repoURL }}
  targetRevision: {{ .Values.targetRevision }}
  ref: values
{{- end -}}
