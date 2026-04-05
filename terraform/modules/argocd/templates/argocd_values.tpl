server:
  service:
    type: ${argocd_server_service_type}
    annotations: {}
  config:
    params:
      server.insecure: "true"

configs:
  cm:
%{ if argocd_reconciliation_timeout != "" ~}
    timeout.reconciliation: "${argocd_reconciliation_timeout}"
%{ endif ~}
    timeout.exec: "${argocd_exec_timeout}"
  params:
    controller.repo.server.timeout.seconds: "${argocd_repo_server_timeout_secs}"
    server.repo.server.timeout.seconds: "${argocd_repo_server_timeout_secs}"

extraObjects:
  - apiVersion: v1
    kind: ConfigMap
    metadata:
      name: argocd-lovely-plugin-config
      namespace: ${argocd_namespace}
    data:
      plugin.yaml: |
        apiVersion: argoproj.io/v1alpha1
        kind: ConfigManagementPlugin
        metadata:
          name: ${argocd_lovely_plugin_name}
        spec:
          version: v1.0
          discover:
            find:
              command:
                - sh
                - -c
                - find . -maxdepth 1 \( -name 'kustomization.yaml' -o -name 'kustomization.yml' \) | head -n 1 | grep .
          generate:
            command:
              - /bin/sh
              - -lc
            args:
              - |
                set -euo pipefail

                TMP_ROOT="$(mktemp -d)"
                trap 'rm -rf "$TMP_ROOT"' EXIT

                env > "$TMP_ROOT/plugin.env"
                while IFS='=' read -r name value; do
                  case "$name" in
                    ARGOCD_ENV_*)
                      export "$${name#ARGOCD_ENV_}=$value"
                      ;;
                  esac
                done < "$TMP_ROOT/plugin.env"

                TMP_APP_DIR="$TMP_ROOT/src"
                mkdir -p "$TMP_APP_DIR"
                tar -C . -cf - . | tar -C "$TMP_APP_DIR" -xf -

                SED_SCRIPT="$TMP_ROOT/env.sed"
                : > "$SED_SCRIPT"
                while IFS='=' read -r name value; do
                  case "$name" in
                    ARGOCD_ENV_*)
                      bare_name="$${name#ARGOCD_ENV_}"
                      escaped_value="$(printf '%s' "$value" | sed -e 's/[\\/&|]/\\&/g')"
                      printf 's|$${%s}|%s|g\n' "$bare_name" "$escaped_value" >> "$SED_SCRIPT"
                      ;;
                  esac
                done < "$TMP_ROOT/plugin.env"

                find "$TMP_APP_DIR" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 |
                  while IFS= read -r -d '' file; do
                    sed -i -f "$SED_SCRIPT" "$file"
                  done

                cat > "$TMP_APP_DIR/argocd-lovely.yaml" <<'EOF'
                apiVersion: argocd-lovely/v1alpha1
                kind: Config
                metadata:
                  name: auto-generated
                spec:
                  sources:
                    - type: kustomize
                      path: .
                EOF

                cd "$TMP_APP_DIR"
                export KUSTOMIZE_ENABLE_HELM=true
                /home/argocd/cmp-server/plugins/${argocd_lovely_plugin_name} generate

repoServer:
  initContainers:
    - name: install-${argocd_lovely_plugin_name}
      image: "${argocd_lovely_plugin_image}"
      imagePullPolicy: IfNotPresent
      command:
        - /bin/sh
        - -c
      args:
        - |
          cp /usr/local/bin/argocd-lovely-plugin /home/argocd/cmp-server/plugins/${argocd_lovely_plugin_name}
          chmod 0555 /home/argocd/cmp-server/plugins/${argocd_lovely_plugin_name}
      volumeMounts:
        - name: plugins
          mountPath: /home/argocd/cmp-server/plugins
  extraContainers:
    - name: lovely-plugin
      image: "{{ default .Values.global.image.repository .Values.repoServer.image.repository }}:{{ default (default .Chart.AppVersion .Values.global.image.tag) .Values.repoServer.image.tag }}"
      imagePullPolicy: "{{ default .Values.global.image.imagePullPolicy .Values.repoServer.image.imagePullPolicy }}"
      command:
        - /var/run/argocd/argocd-cmp-server
      env:
        - name: ARGOCD_EXEC_TIMEOUT
          value: "${argocd_exec_timeout}"
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: var-files
          mountPath: /var/run/argocd
        - name: plugins
          mountPath: /home/argocd/cmp-server/plugins
        - name: lovely-plugin-config
          mountPath: /home/argocd/cmp-server/config/plugin.yaml
          subPath: plugin.yaml
        - name: cmp-tmp
          mountPath: /tmp
  volumes:
    - name: lovely-plugin-config
      configMap:
        name: argocd-lovely-plugin-config
    - name: cmp-tmp
      emptyDir: {}
