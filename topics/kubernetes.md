---
topic: kubernetes
maintainer: thomaszachmann
---

# Kubernetes

Four competencies covering the failures that actually consume time in
operations: permissions, traffic that does not arrive, pods that will not
schedule, and rollouts that lie about their health.

## Competency: RBAC

### Why this matters
Getting permissions wrong either blocks a deployment at the worst moment or
grants far more access than anyone intended.

### Level 1 — basics
Can name and distinguish Role vs ClusterRole, RoleBinding vs
ClusterRoleBinding.

### Level 2 — can apply
Can design a minimal role for a concrete use case and justify why it is
minimal.

### Level 3 — can explain
Can derive why a ClusterRoleBinding against a Role does not work.

### Common misconceptions
- Reads ClusterRole as "applies cluster-wide" instead of "is not
  namespace-scoped"
- Assumes the binding inherits the namespace of the role rather than the other
  way round
- Believes removing a RoleBinding revokes access immediately for a token
  already in use, without considering caching

## Competency: Networking and Services

### Why this matters
When traffic does not reach a pod the cause is nearly always one of three
mappings, and knowing which to check first is the difference between five
minutes and an afternoon.

### Level 1 — basics
Can say what a Service does and distinguish ClusterIP, NodePort and
LoadBalancer.

### Level 2 — can apply
Given a Service and a Deployment that do not connect, can name the three
things that must line up — label selector, container port, readiness — and
check each one with a command.

### Level 3 — can explain
Can explain why a Service with a correct selector can still have no endpoints,
and what the Endpoints or EndpointSlice object reveals that the Service does
not.

### Common misconceptions
- Reads `targetPort` as the port the client connects to, rather than the port
  the container listens on
- Pictures a Service as a proxy process sitting in front of the pods, rather
  than as forwarding rules on every node
- Assumes a pod joins the Service as soon as it is Running, ignoring readiness

## Competency: Scheduling and Resources

### Why this matters
Pending pods and OOMKills are the two most common production surprises, and
both come from the same confusion between what is reserved and what is
enforced.

### Level 1 — basics
Can distinguish requests from limits and say which one the scheduler uses.

### Level 2 — can apply
Given a Pending pod, can determine from `kubectl describe` whether the cause
is insufficient capacity, a taint, or a node selector, and say which command
showed them.

### Level 3 — can explain
Can explain how requests and limits together determine the QoS class, and what
that class means when a node comes under memory pressure.

### Common misconceptions
- Treats a request as a cap on usage rather than a reservation for scheduling
- Treats CPU and memory limits as the same kind of enforcement, missing that
  one throttles and the other kills
- Concludes from a Pending pod that the cluster is out of capacity, without
  checking taints and affinity first

## Competency: Probes and Rollouts

### Why this matters
A wrong probe turns a healthy deployment into an outage, and a missing one
turns a broken deployment into a silent failure.

### Level 1 — basics
Can name the three probe types and say what failing each one causes to happen.

### Level 2 — can apply
Can choose appropriate probes for a service with a slow start, and explain why
a liveness probe is the dangerous one to get wrong in that case.

### Level 3 — can explain
Can explain how readiness interacts with `maxUnavailable` and `maxSurge`
during a rolling update, and how a bad readiness probe can either stall a
rollout or let a broken version through.

### Common misconceptions
- Reads liveness as "is this healthy" rather than "should this be restarted"
- Uses the same endpoint and the same timings for liveness and readiness
- Believes a failing readiness probe restarts the pod
