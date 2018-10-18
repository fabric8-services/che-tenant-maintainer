import ceylon.language.meta.declaration {
    ClassDeclaration,
    Package,
    FunctionDeclaration
}
import ceylon.language.meta.model {
    Class
}

shared Maintenance? withDefaultValues<Maintenance>(Class<Maintenance,Nothing> maintenance)
    given Maintenance satisfies NamespaceMaintenance =>
    maintenance.declaration
        .containingPackage
        .members<FunctionDeclaration>().find((fun) =>
            fun.parameterDeclarations.empty &&
            fun.typeParameterDeclarations.empty &&
            fun.openType == maintenance.declaration.openType
        )?.apply<Maintenance>()?.apply();

shared Map<String, Class<NamespaceMaintenance,Nothing>> maintenances = map {
    for (pkg in `module`.members.narrow<Package>())
        if (pkg.name != `module`.name)
        for (cls in pkg.annotatedMembers<ClassDeclaration, Named>())
        if (exists name = cls.annotations<Named>().first?.naming,
            exists type = cls.extendedType,
            `class NamespaceMaintenance` == type.declaration)
        name.apply<String, Nothing>().get() -> cls.classApply<NamespaceMaintenance>()
};
