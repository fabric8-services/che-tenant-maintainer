"The annotation class for the [[maintenanceFinished]] annotation."
shared final sealed annotation class MaintenanceFinished()
        satisfies OptionalAnnotation<MaintenanceFinished> {
}

"Annotation to mark that a one-shot maintenance action is now fully processed."
shared annotation MaintenanceFinished maintenanceFinished()
        => MaintenanceFinished();
