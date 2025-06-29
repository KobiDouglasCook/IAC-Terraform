apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloudwatch-agent
  namespace: ${namespace}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cloudwatch-agent-role
rules:
  - apiGroups: [""]
    resources: ["pods", "nodes", "namespaces"]
    verbs: ["list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloudwatch-agent-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cloudwatch-agent-role
subjects:
  - kind: ServiceAccount
    name: cloudwatch-agent
    namespace: ${namespace}
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cloudwatch-agent
  namespace: ${namespace}
spec:
  selector:
    matchLabels:
      name: cloudwatch-agent
  template:
    metadata:
      labels:
        name: cloudwatch-agent
    spec:
      serviceAccountName: cloudwatch-agent
      containers:
        - name: cloudwatch-agent
          image: public.ecr.aws/cloudwatch-agent/cloudwatch-agent:latest
          resources:
            limits:
              memory: 200Mi
            requests:
              cpu: 100m
              memory: 200Mi
          env:
            - name: HOST_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
          volumeMounts:
            - name: rootfs
              mountPath: /rootfs
              readOnly: true
            - name: varlog
              mountPath: /var/log
              readOnly: true
            - name: dockersock
              mountPath: /var/run/docker.sock
              readOnly: true
      volumes:
        - name: rootfs
          hostPath:
            path: /
        - name: varlog
          hostPath:
            path: /var/log
        - name: dockersock
          hostPath:
            path: /var/run/docker.sock
