import io.fabric8.kubernetes.client.dsl {
    Resource
}

shared Boolean() buildTimeout(Integer timeout) {
    value end = system.milliseconds + timeout;
    return () => system.milliseconds > end;
}
shared Integer second = 1000;

" Avoid name collisions with ceylon.language::Resource"
shared interface KubernetesResource<T1,T2> => Resource<T1,T2>;