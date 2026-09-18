// Compatibility barrel for existing imports. Student presentation is split into
// independently compiled, bounded legacy libraries until MOB-070 replaces
// their direct preview persistence with repository-backed feature slices.
export 'legacy/student/presentation/student_account_pages.dart'
    show StudentProfilePage, StudentSettingsPage;
export 'legacy/student/presentation/student_classwork_page.dart'
    show StudentClassworkPage;
export 'legacy/student/presentation/student_home_page.dart'
    show StudentHomePage;
export 'legacy/student/presentation/student_notebook_page.dart'
    show StudentNotebookPage;
export 'legacy/student/presentation/student_progress_page.dart'
    show StudentProgressPage;
export 'legacy/student/presentation/student_shell.dart' show StudentShell;
