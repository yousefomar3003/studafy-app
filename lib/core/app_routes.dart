/// The named routes the app registers, in one place.
///
/// These were literals repeated in the composition root and again in the
/// screens that navigate to them, so a rename could leave the two disagreeing
/// and only fail at runtime. Route names are navigation vocabulary shared by
/// every zone - a feature has to be able to say where it is going without
/// importing the wiring that builds the destination - which is why they live
/// in core rather than in `lib/app`.
library;

/// The role picker, and the start of every signed-out journey.
const rolesRoute = '/roles';

/// First run for an account that belongs to nothing yet.
///
/// Takes the chosen [UserRole] as its route argument, because the person has
/// already picked one and should not be asked twice.
const onboardingRoute = '/onboarding';

const teacherRoute = '/teacher';
const parentRoute = '/parent';
const studentRoute = '/student';
