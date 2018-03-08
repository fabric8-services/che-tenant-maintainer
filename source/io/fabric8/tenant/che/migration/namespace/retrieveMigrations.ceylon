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

shared [Class<NamespaceMigration,Nothing>*] migrationTypes = [
    for (pkg in `module`.members.narrow<Package>())
        if (pkg.name != `module`.name)
        for (cls in pkg.members<ClassDeclaration>())
        if (exists extendedType = cls.extendedType,
            extendedType.declaration == `NamespaceMigration`.declaration)
        cls.classApply<NamespaceMigration>()
];

shared [String*] migrationNames => migrationTypes
    .map(withDefaultValues).coalesced
    .map(NamespaceMigration.name)
    .sequence();
