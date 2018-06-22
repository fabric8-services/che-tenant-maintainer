import ceylon.language.meta.declaration {
    ClassDeclaration,
    Package,
    FunctionDeclaration
}
import ceylon.language.meta.model {
    Class
}

shared Migration? withDefaultValues<Migration>(Class<Migration,Nothing> migration)
    given Migration satisfies NamespaceMigration =>
    migration.declaration
        .containingPackage
        .members<FunctionDeclaration>().find((fun) =>
            fun.parameterDeclarations.empty &&
            fun.typeParameterDeclarations.empty &&
            fun.openType == migration.declaration.openType
        )?.apply<Migration>()?.apply();

shared Map<String, Class<NamespaceMigration,Nothing>> migrations = map {
    for (pkg in `module`.members.narrow<Package>())
        if (pkg.name != `module`.name)
        for (cls in pkg.annotatedMembers<ClassDeclaration, Named>())
        if (exists name = cls.annotations<Named>().first?.naming,
            exists type = cls.extendedType,
            `class NamespaceMigration` == type.declaration)
        name.apply<String, Nothing>().get() -> cls.classApply<NamespaceMigration>()
};
