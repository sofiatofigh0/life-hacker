import Foundation

// MARK: - Programs

/// One exercise line in a program day: the catalog name, sets, and rep range
/// (or a time/hold expressed as text).
public struct ProgramExercise: Hashable, Sendable {
    public let name: String
    public let sets: Int
    public let reps: String
    public let note: String?

    public init(_ name: String, sets: Int, reps: String, note: String? = nil) {
        self.name = name; self.sets = sets; self.reps = reps; self.note = note
    }
}

/// A day of a program. Becomes a `TemplateEntity` when added.
public struct ProgramDay: Hashable, Sendable {
    public let name: String
    public let focus: String
    /// Suggested weekday (1 = Sunday … 7 = Saturday); 0 leaves it unscheduled.
    public let suggestedWeekday: Int
    public let exercises: [ProgramExercise]
    public let coachNote: String?

    public init(name: String, focus: String, suggestedWeekday: Int, exercises: [ProgramExercise], coachNote: String? = nil) {
        self.name = name; self.focus = focus; self.suggestedWeekday = suggestedWeekday; self.exercises = exercises; self.coachNote = coachNote
    }
}

public struct Program: Hashable, Sendable {
    public let name: String
    public let summary: String
    public let days: [ProgramDay]

    public init(name: String, summary: String, days: [ProgramDay]) { self.name = name; self.summary = summary; self.days = days }
}

/// Built-in programs. Like the exercise catalog this is code: adding a day or
/// a program in an update never touches stored data. Every exercise name must
/// exist in `ExerciseCatalog` (tested).
public enum ProgramCatalog {
    private static func x(_ name: String, _ sets: Int, _ reps: String, _ note: String? = nil) -> ProgramExercise {
        ProgramExercise(name, sets: sets, reps: reps, note: note)
    }

    static let upperWarmup: [ProgramExercise] = [
        x("Arm Circles", 1, "10 fwd + 10 back"),
        x("Wall Slide", 2, "10"),
        x("Band External Rotation", 2, "12–15"),
        x("Band Pull-Apart", 1, "15"),
    ]

    static let lowerWarmup: [ProgramExercise] = [
        x("Glute Bridge", 1, "15"),
        x("Banded Lateral Walk", 2, "10–15 each way"),
        x("Bodyweight Hip Hinge", 1, "10"),
    ]

    static let upperDay1 = ProgramDay(
        name: "Upper 1 · Shoulders, Triceps, Chest",
        focus: "Shoulders, triceps, chest and posture",
        suggestedWeekday: 2,
        exercises: upperWarmup + [
            x("Incline Dumbbell Press", 3, "10–12", "Warm-up set first; about 15–20 lb each"),
            x("Cable Lateral Raise", 3, "12–15", "About 7.5–12.5 lb a side"),
            x("Rope Pushdown", 3, "10–15", "About 25–35 lb"),
            x("Overhead Cable Extension", 3, "12–15", "Rope; about 20–30 lb"),
            x("Reverse Pec Deck", 3, "12–15", "About 30–45 lb"),
            x("Face Pull", 2, "15–20", "About 20–30 lb"),
            x("Doorway Pec Stretch", 2, "30–45 s"),
            x("Chin Tuck", 1, "10 × 3 s hold"),
        ],
        coachNote: "Finish with an optional 15–20 minute cardio video.")

    static let lowerDay1 = ProgramDay(
        name: "Lower 1 · Glutes & Hamstrings",
        focus: "Primary glute-building day",
        suggestedWeekday: 3,
        exercises: lowerWarmup + [
            x("Hip Thrust", 4, "8–12", "Light warm-up set first. Get progressively stronger here."),
            x("Romanian Deadlift", 3, "8–12", "Get progressively stronger here."),
            x("Single-Leg Leg Press", 3, "10–12 each leg"),
            x("Cable Kickback", 3, "12–15 each leg"),
            x("Hamstring Curl", 3, "10–15", "Seated or lying"),
            x("Hip Abduction", 3, "15–20"),
        ],
        coachNote: "The hip thrust and RDL are the lifts to progress. Optional 10–15 minutes easy cardio after.")

    static let upperDay2 = ProgramDay(
        name: "Upper 2 · Back & Posture",
        focus: "Back, posture and triceps",
        suggestedWeekday: 5,
        exercises: upperWarmup + [
            x("Neutral-Grip Lat Pulldown", 3, "10–12", "Warm-up set 25–35 lb first; start around 45–50 lb"),
            x("Chest-Supported Row", 3, "10–12"),
            x("Reverse Pec Deck", 3, "12–15", "About 30–45 lb"),
            x("Cable Y-Raise", 2, "12–15", "About 5–10 lb a side"),
            x("Cross-Body Cable Triceps Extension", 3, "12–15", "Around 10–15 lb a side"),
            x("Bicep Curl", 2, "12–15", "Dumbbells, around 10–15 lb"),
            x("Band Pull-Apart", 2, "15–20"),
            x("Band External Rotation", 2, "15"),
            x("Doorway Pec Stretch", 2, "30–45 s"),
        ],
        coachNote: "The posture and back day. Optional 15–20 minute cardio video after.")

    static let lowerDay2 = ProgramDay(
        name: "Lower 2 · Glute Shape",
        focus: "Upper and side glutes; shape over load",
        suggestedWeekday: 6,
        exercises: lowerWarmup + [
            x("Hip Thrust", 3, "10–12", "Or glute bridge"),
            x("Step-Up", 3, "8–10 each side", "Low box, only if the knee is completely comfortable"),
            x("Single-Leg Romanian Deadlift", 3, "10–12 each side"),
            x("Cable Diagonal Kickback", 3, "12–15 each side"),
            x("Hip Abduction", 3, "15–20"),
            x("Hamstring Curl", 3, "12–15"),
            x("Frog Pump", 2, "20", "Or glute bridge pulses"),
        ],
        coachNote: "If step-ups bother the knee at all, swap in another glute exercise. Optional 10–15 minutes cardio after.")

    static let lowerDay3 = ProgramDay(
        name: "Lower 3 · Glutes & Legs, Lighter",
        focus: "Lighter glute and leg day",
        suggestedWeekday: 7,
        exercises: [
            x("Glute Activation Circuit", 1, "2–3 min"),
            x("Leg Press", 3, "10–15", "Comfortable range of motion"),
            x("Dumbbell Romanian Deadlift", 3, "10–12", "Or cable RDL"),
            x("Glute-Biased Back Extension", 3, "10–15"),
            x("Cable Kickback", 3, "15 each side"),
            x("Hip Abduction", 3, "15–20"),
            x("Hamstring Curl", 3, "12–15"),
            x("Standing Calf Raise", 3, "12–20"),
        ],
        coachNote: "Deliberately lighter so the legs are not hammered three times a week. Optional 10–20 minutes gentle cardio after.")

    public static let glutesAndPosture = Program(
        name: "Glutes & Posture · 5 days",
        summary: "Two upper days for shoulders, back and posture; three lower days built around the hip thrust and RDL.",
        days: [upperDay1, lowerDay1, upperDay2, lowerDay2, lowerDay3])

    public static let all: [Program] = [glutesAndPosture]
}
