import ceylon.language.meta.declaration {
    ClassDeclaration,
    ValueDeclaration
}

"The annotation class for the [[naming]] annotation."
shared final annotation class Named(shared ValueDeclaration naming)
        satisfies OptionalAnnotation<Named, ClassDeclaration> {
}

"Annotation to define the naming of a migration or maintenance action."
shared annotation Named named(ValueDeclaration naming)
        => Named(naming);
