"The annotation class for the [[migrationFinished]] annotation."
shared final sealed annotation class MigrationFinished()
        satisfies OptionalAnnotation<MigrationFinished> {
}

"Annotation to mark that a migration is now fully processed."
shared annotation MigrationFinished migrationFinished()
        => MigrationFinished();
