# Specialized Domains

Legacy modernization, embedded systems, and game development.

## Legacy Modernization

### Migration Strategies

| Strategy | Risk | Speed | When |
|----------|------|-------|------|
| Strangler Fig | Low | Slow | Large monoliths, gradual migration |
| Big Bang | High | Fast | Small apps, clear scope |
| Branch by Abstraction | Medium | Medium | Shared codebase, feature toggles |
| Database First | Medium | Slow | Data-centric apps |

### Modernization Steps
1. **Assess** — Map dependencies, identify boundaries, measure tech debt
2. **Containerize** — Wrap legacy in Docker for environment isolation
3. **Extract** — Pull bounded contexts into services
4. **Strangle** — Route traffic gradually from old to new
5. **Retire** — Decommission legacy components

## Embedded Systems

| Area | Pattern |
|------|---------|
| Memory | Static allocation preferred; avoid heap fragmentation |
| RTOS | FreeRTOS, Zephyr; priority-based scheduling |
| Communication | UART, SPI, I2C, CAN bus protocols |
| Power | Sleep modes, interrupt-driven wake |
| Safety | Watchdog timers, stack overflow detection |
| Testing | Hardware-in-the-loop (HIL), emulators |

### Best Practices
- Fixed-point math over floating-point when FPU absent
- Volatile for hardware-mapped registers
- Minimal dynamic allocation; pool allocators when needed
- Interrupt handlers: keep short, defer work to tasks
- Define clear hardware abstraction layer (HAL)

## Game Development

| Area | Pattern |
|------|---------|
| Architecture | Entity-Component-System (ECS), game loop |
| Physics | Fixed timestep update, interpolated rendering |
| Rendering | Scene graph, spatial partitioning (octree/BVH) |
| Networking | Client prediction, server reconciliation, lag compensation |
| Performance | Object pooling, LOD, culling, batching |
| State | State machines for AI, animation, game flow |

### Game Loop Pattern
```
while (running) {
    processInput();
    update(fixedDeltaTime);     // physics at fixed rate
    render(interpolation);       // smooth visual at variable rate
}
```
