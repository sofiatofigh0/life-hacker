import Foundation

// MARK: - Types

public enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest, back, shoulders, biceps, triceps, forearms, quads, hamstrings, glutes, calves, core, fullBody

    public var label: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .core: return "Core"
        case .fullBody: return "Full body"
        }
    }
}

public enum Equipment: String, CaseIterable, Codable, Sendable {
    case barbell, dumbbell, cable, machine, bodyweight, kettlebell, band, smithMachine

    public var label: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .cable: return "Cable"
        case .machine: return "Machine"
        case .bodyweight: return "Bodyweight"
        case .kettlebell: return "Kettlebell"
        case .band: return "Band"
        case .smithMachine: return "Smith machine"
        }
    }
}

public struct ExerciseDefinition: Hashable, Sendable {
    public let name: String
    public let muscleGroup: MuscleGroup
    public let equipment: Equipment
    public let summary: String
    public let tips: [String]

    public init(name: String, muscleGroup: MuscleGroup, equipment: Equipment, summary: String, tips: [String]) {
        self.name = name; self.muscleGroup = muscleGroup; self.equipment = equipment; self.summary = summary; self.tips = tips
    }

    /// "Glutes · Barbell"
    public var subtitle: String { "\(muscleGroup.label) · \(equipment.label)" }
}

// MARK: - Catalog

/// The built-in exercise library.
///
/// This is deliberately *code*, not stored data: the database holds only a
/// name, summary, and tips per exercise (plus a custom flag). Muscle group and
/// equipment are looked up here by name at display time. That means the
/// library can grow or be corrected in any update with no schema change and no
/// migration — the user's workout history references exercises by name and is
/// untouched.
///
/// Names are unique and stable: they are the key that sessions, templates, and
/// the demo seeder use. Renaming one is a data change and should be avoided.
public enum ExerciseCatalog {
    private static func e(_ name: String, _ group: MuscleGroup, _ equipment: Equipment, _ summary: String, _ tips: String...) -> ExerciseDefinition {
        ExerciseDefinition(name: name, muscleGroup: group, equipment: equipment, summary: summary, tips: tips)
    }

    // Split by group so no single array literal is large enough to slow the type checker.

    static let chest: [ExerciseDefinition] = [
        e("Barbell Bench Press", .chest, .barbell, "Flat horizontal press; the primary chest builder.",
          "Feet planted, slight arch, shoulder blades pinned back", "Bar touches lower chest, elbows about 45° from the torso", "Press up and slightly back toward the rack"),
        e("Incline Barbell Bench Press", .chest, .barbell, "Press on a 30–45° incline for the upper chest.",
          "Keep the incline modest — steeper shifts work to the shoulders", "Lower to the upper chest, not the neck"),
        e("Decline Barbell Bench Press", .chest, .barbell, "Press on a decline for the lower chest.",
          "Hook feet securely", "Shorter range — control the bottom"),
        e("Dumbbell Bench Press", .chest, .dumbbell, "Flat press with independent arms and a deeper stretch.",
          "Kick the dumbbells up with your knees", "Lower until elbows are just below the bench", "Don't clang the weights together at the top"),
        e("Incline Dumbbell Press", .chest, .dumbbell, "Upper-chest press with a fuller range than a bar.",
          "Bench at 30°", "Palms can rotate slightly inward at the top"),
        e("Dumbbell Fly", .chest, .dumbbell, "Wide arc that stretches and isolates the pecs.",
          "Slight, fixed elbow bend the whole way", "Stop when you feel the stretch — don't chase depth", "Squeeze as if hugging a tree"),
        e("Incline Dumbbell Fly", .chest, .dumbbell, "Fly on an incline to bias the upper chest.",
          "Keep the arc wide and the elbows soft", "Lighter than you think"),
        e("Cable Fly", .chest, .cable, "Constant-tension fly from a cable crossover.",
          "Step forward into a staggered stance", "Bring hands together in front of the chest", "Slight lean forward, chest up"),
        e("Low-to-High Cable Fly", .chest, .cable, "Cables set low, arcing upward for the upper chest.",
          "Finish with hands at shoulder height", "Control the eccentric"),
        e("High-to-Low Cable Fly", .chest, .cable, "Cables set high, arcing down for the lower chest.",
          "Finish with hands near the hips", "Keep shoulders down and back"),
        e("Chest Press Machine", .chest, .machine, "Guided pressing path; good for high reps or fatigue.",
          "Set the seat so handles are at mid-chest", "Don't lock elbows hard at the end"),
        e("Pec Deck", .chest, .machine, "Machine fly with the arms supported.",
          "Elbows slightly below shoulder height", "Pause and squeeze in the middle"),
        e("Push-Up", .chest, .bodyweight, "The fundamental horizontal push.",
          "Body in one straight line, glutes tight", "Elbows about 45° from the torso", "Chest to the floor, not chin"),
        e("Incline Push-Up", .chest, .bodyweight, "Hands elevated — easier, good for building volume.",
          "The higher the hands, the easier", "Same straight-body rule"),
        e("Decline Push-Up", .chest, .bodyweight, "Feet elevated — harder, biases the upper chest.",
          "Keep hips from sagging", "Hands slightly wider than shoulders"),
        e("Dip", .chest, .bodyweight, "Parallel-bar dip; lean forward to emphasise chest.",
          "Lean forward for chest, upright for triceps", "Elbows to about 90°", "Don't let shoulders roll forward at the bottom"),
        e("Smith Machine Bench Press", .chest, .smithMachine, "Fixed-path bench press.",
          "Position the bench so the bar touches mid-chest", "Good for controlled sets when fatigued"),
    ]

    static let back: [ExerciseDefinition] = [
        e("Conventional Deadlift", .back, .barbell, "Hip-hinge pull from the floor; whole posterior chain.",
          "Bar over mid-foot, shins to the bar", "Brace, then push the floor away", "Hips and shoulders rise together", "Finish tall — don't lean back"),
        e("Sumo Deadlift", .back, .barbell, "Wide-stance pull with a more upright torso.",
          "Knees track over toes", "Spread the floor with your feet", "Keep the bar close"),
        e("Trap Bar Deadlift", .back, .barbell, "Hex-bar pull; friendlier on the lower back.",
          "Sit back into the pull", "Drive through the whole foot"),
        e("Barbell Row", .back, .barbell, "Bent-over row for mid-back thickness.",
          "Hinge to about 45°, back flat", "Pull to the lower ribs", "Elbows lead, no torso heave"),
        e("Pendlay Row", .back, .barbell, "Row from a dead stop on the floor each rep.",
          "Torso parallel to the floor", "Explosive pull, controlled lower"),
        e("T-Bar Row", .back, .barbell, "Landmine row; loads the mid-back well.",
          "Chest on the pad if there is one", "Squeeze shoulder blades at the top"),
        e("Lat Pulldown", .back, .cable, "Vertical back pull.",
          "Drive elbows down and back", "Bar to the upper chest", "Lean back only slightly"),
        e("Close-Grip Lat Pulldown", .back, .cable, "V-handle pulldown for a longer lat stretch.",
          "Let the lats stretch fully at the top", "Pull to the sternum"),
        e("Straight-Arm Pulldown", .back, .cable, "Lat isolation with locked elbows.",
          "Slight elbow bend, fixed", "Sweep the bar to the thighs", "Feel it in the lats, not the triceps"),
        e("Seated Row", .back, .cable, "Horizontal back pull.",
          "Keep chest tall", "Pull to the navel", "Don't rock back with the torso"),
        e("Single-Arm Cable Row", .back, .cable, "One-arm row that lets the scapula move freely.",
          "Reach forward at the start", "Drive the elbow back past the torso"),
        e("Face Pull", .back, .cable, "Rope pull to the face for rear delts and upper back.",
          "Rope at face height", "Pull apart, thumbs to ears", "Light weight, high reps"),
        e("Dumbbell Row", .back, .dumbbell, "One-arm row supported on a bench.",
          "Flat back, opposite hand and knee on the bench", "Pull to the hip, not the shoulder", "Full stretch at the bottom"),
        e("Chest-Supported Row", .back, .dumbbell, "Row lying on an incline bench; removes the lower back.",
          "Chest stays glued to the pad", "Pause with shoulder blades together"),
        e("Dumbbell Pullover", .back, .dumbbell, "Arc overhead for lats and serratus.",
          "Hips low, upper back on the bench", "Keep a slight elbow bend", "Stop when you feel the stretch"),
        e("Pull-Up", .back, .bodyweight, "Overhand vertical pull; the benchmark back exercise.",
          "Start from a dead hang", "Chin over the bar, chest to the bar if possible", "Lower under control"),
        e("Chin-Up", .back, .bodyweight, "Underhand pull-up; more biceps.",
          "Hands shoulder-width, palms facing you", "Drive elbows to the ribs"),
        e("Neutral-Grip Pull-Up", .back, .bodyweight, "Palms facing each other; easiest on the shoulders.",
          "Same standards as a pull-up", "Good starting variation"),
        e("Inverted Row", .back, .bodyweight, "Horizontal bodyweight row under a bar.",
          "Body straight from heels to head", "Pull chest to the bar", "Lower the bar to make it harder"),
        e("Assisted Pull-Up", .back, .machine, "Machine-assisted pull-up for building toward the real thing.",
          "Reduce assistance gradually", "Same full range as a pull-up"),
        e("Machine Row", .back, .machine, "Seated row machine with chest pad.",
          "Adjust the pad so arms extend fully", "Squeeze and pause"),
        e("Machine Pulldown", .back, .machine, "Plate-loaded pulldown.",
          "Elbows down, not back", "Control the return"),
        e("Back Extension", .back, .bodyweight, "Hip extension on a 45° bench for spinal erectors and glutes.",
          "Hinge at the hips, not the lower back", "Stop in line with the body — don't hyperextend", "Hold a plate to progress"),
        e("Kettlebell Swing", .back, .kettlebell, "Explosive hip hinge; posterior chain and conditioning.",
          "Hike the bell back, snap the hips", "Arms are ropes — the hips do the work", "Stand tall at the top, glutes tight"),
        e("Band Pull-Apart", .back, .band, "Rear delt and upper-back activation.",
          "Arms straight, pull to the chest", "Great as a warm-up"),
        e("Meadows Row", .back, .barbell, "Landmine row from the side; strong lat stretch.",
          "Staggered stance, hinge over", "Elbow drives up and back"),
    ]

    static let shoulders: [ExerciseDefinition] = [
        e("Shoulder Press", .shoulders, .dumbbell, "Overhead pressing movement.",
          "Brace your core", "Press slightly back so the weights end over the ears", "Don't flare the ribs"),
        e("Overhead Press", .shoulders, .barbell, "Standing barbell press; the strength standard for shoulders.",
          "Bar starts on the collarbone", "Squeeze glutes, tuck ribs", "Move the head back, press, then through"),
        e("Seated Barbell Press", .shoulders, .barbell, "Seated overhead press with back support.",
          "Bench nearly upright", "Full lockout overhead"),
        e("Arnold Press", .shoulders, .dumbbell, "Rotating press that hits all three delt heads.",
          "Start palms facing you at chin height", "Rotate as you press", "Lighter than a normal press"),
        e("Lateral Raise", .shoulders, .dumbbell, "Side delt isolation.",
          "Lead with elbows", "Raise to shoulder height only", "Slight forward lean, pinkies a touch higher"),
        e("Cable Lateral Raise", .shoulders, .cable, "Constant-tension side raise from a low pulley.",
          "Cable behind the body", "Slow, controlled lower"),
        e("Front Raise", .shoulders, .dumbbell, "Front delt isolation.",
          "Raise to eye level", "Alternate arms to reduce swinging"),
        e("Rear Delt Fly", .shoulders, .dumbbell, "Bent-over fly for the rear delts.",
          "Hinge to near-parallel", "Lead with the pinkies", "Light weight — the rear delts are small"),
        e("Reverse Pec Deck", .shoulders, .machine, "Machine rear-delt fly.",
          "Handles at shoulder height", "Squeeze between the shoulder blades"),
        e("Upright Row", .shoulders, .barbell, "Vertical pull to the chest for side delts and traps.",
          "Wide grip to spare the shoulders", "Elbows high, bar to the sternum"),
        e("Machine Shoulder Press", .shoulders, .machine, "Guided overhead press.",
          "Seat so handles start at ear height", "Don't lock out hard"),
        e("Landmine Press", .shoulders, .barbell, "Angled press; shoulder-friendly.",
          "Press up and forward", "Brace the core, no lean-back"),
        e("Barbell Shrug", .shoulders, .barbell, "Traps; straight up and down.",
          "Shrug to the ears, pause", "No rolling"),
        e("Dumbbell Shrug", .shoulders, .dumbbell, "Traps with dumbbells at the sides.",
          "Let the arms hang, shrug straight up", "Hold the top for a beat"),
        e("Pike Push-Up", .shoulders, .bodyweight, "Inverted-V push-up for shoulders.",
          "Hips high, head toward the floor", "Elevate feet to progress"),
        e("Handstand Push-Up", .shoulders, .bodyweight, "Wall-supported overhead press with bodyweight.",
          "Kick up against a wall", "Head to the floor, press to lockout", "Scale with a pike push-up first"),
        e("Band Face Pull", .shoulders, .band, "Face pull with a band; rear delts and rotator cuff.",
          "Pull to the forehead, hands apart", "Squeeze the shoulder blades"),
        e("Cuban Rotation", .shoulders, .dumbbell, "External rotation for rotator cuff health.",
          "Elbows at shoulder height", "Very light weight"),
    ]

    static let biceps: [ExerciseDefinition] = [
        e("Bicep Curl", .biceps, .dumbbell, "Elbow flexion movement.",
          "Keep elbows quiet", "Supinate as you curl", "Lower slowly"),
        e("Barbell Curl", .biceps, .barbell, "Two-hand curl; the most weight you'll curl.",
          "Elbows pinned to the sides", "No swinging — reduce the weight if you do"),
        e("EZ-Bar Curl", .biceps, .barbell, "Angled grip; easier on the wrists.",
          "Same elbow rule", "Full range top and bottom"),
        e("Hammer Curl", .biceps, .dumbbell, "Neutral-grip curl for the brachialis and forearm.",
          "Palms face each other throughout", "Don't let elbows drift forward"),
        e("Incline Dumbbell Curl", .biceps, .dumbbell, "Curl on an incline bench for a long-head stretch.",
          "Let the arms hang straight down", "Curl without moving the upper arm"),
        e("Preacher Curl", .biceps, .dumbbell, "Curl with arms braced on a pad; no cheating.",
          "Pad in the armpits", "Don't fully lock out at the bottom under load"),
        e("Concentration Curl", .biceps, .dumbbell, "Seated single-arm curl, elbow on the thigh.",
          "Elbow inside the knee", "Squeeze at the top"),
        e("Cable Curl", .biceps, .cable, "Constant-tension curl from a low pulley.",
          "Step back slightly for tension at the bottom", "Elbows stay put"),
        e("Spider Curl", .biceps, .dumbbell, "Curl face-down on an incline bench; peak contraction.",
          "Arms hang straight down", "Squeeze hard at the top"),
        e("Machine Curl", .biceps, .machine, "Guided curl with arm support.",
          "Seat so the pad meets the upper arm", "Control the lower"),
        e("Reverse Curl", .biceps, .barbell, "Overhand curl; brachioradialis and forearms.",
          "Lighter than a normal curl", "Wrists straight"),
        e("Zottman Curl", .biceps, .dumbbell, "Curl up palms-up, lower palms-down.",
          "Rotate at the top", "Slow eccentric"),
        e("Band Curl", .biceps, .band, "Curl with a resistance band.",
          "Stand on the band, elbows fixed", "Increasing tension toward the top"),
    ]

    static let triceps: [ExerciseDefinition] = [
        e("Tricep Pushdown", .triceps, .cable, "Cable triceps movement.",
          "Fully extend with control", "Elbows pinned to the sides", "Straight bar or rope"),
        e("Rope Pushdown", .triceps, .cable, "Rope pushdown; split the ends at the bottom.",
          "Pull the rope apart at the bottom", "Elbows stay at the ribs"),
        e("Overhead Cable Extension", .triceps, .cable, "Overhead extension for the long head.",
          "Elbows point forward", "Full stretch behind the head"),
        e("Skull Crusher", .triceps, .barbell, "Lying extension to the forehead or behind the head.",
          "Lower behind the head for a bigger stretch", "Elbows stay pointed to the ceiling", "Use an EZ bar if the wrists complain"),
        e("Close-Grip Bench Press", .triceps, .barbell, "Bench press with a narrow grip.",
          "Hands about shoulder-width, not narrower", "Elbows tucked", "Touch low on the chest"),
        e("Overhead Dumbbell Extension", .triceps, .dumbbell, "Single dumbbell held overhead with both hands.",
          "Elbows close to the head", "Lower until you feel the stretch"),
        e("Dumbbell Kickback", .triceps, .dumbbell, "Extension with the upper arm parallel to the floor.",
          "Upper arm stays still", "Light weight, full lockout"),
        e("Tricep Dip", .triceps, .bodyweight, "Upright parallel-bar dip biased to triceps.",
          "Torso vertical", "Elbows to 90°, then lock out"),
        e("Bench Dip", .triceps, .bodyweight, "Dip with hands on a bench behind you.",
          "Keep hips close to the bench", "Don't go below 90° at the elbow"),
        e("Diamond Push-Up", .triceps, .bodyweight, "Push-up with hands together.",
          "Thumbs and index fingers form a diamond", "Elbows track back, not out"),
        e("JM Press", .triceps, .barbell, "Hybrid of a close-grip press and a skull crusher.",
          "Bar travels toward the chin", "Moderate weight"),
        e("Machine Tricep Extension", .triceps, .machine, "Guided extension with arm support.",
          "Elbows on the pad", "Full extension"),
        e("Band Pushdown", .triceps, .band, "Pushdown with a band anchored overhead.",
          "Elbows fixed at the sides", "Lock out fully"),
    ]

    static let forearms: [ExerciseDefinition] = [
        e("Wrist Curl", .forearms, .dumbbell, "Palms-up wrist flexion.",
          "Forearms on the bench, wrists over the edge", "Let the weight roll to the fingertips"),
        e("Reverse Wrist Curl", .forearms, .dumbbell, "Palms-down wrist extension.",
          "Lighter than a wrist curl", "Small, controlled range"),
        e("Farmer's Carry", .forearms, .dumbbell, "Walk with heavy weights at the sides.",
          "Stand tall, shoulders back", "Walk for distance or time"),
        e("Plate Pinch", .forearms, .bodyweight, "Pinch-grip hold on smooth plates.",
          "Smooth side out", "Hold for time"),
        e("Dead Hang", .forearms, .bodyweight, "Hang from a bar for grip and shoulder health.",
          "Relax the shoulders or pack them — both are useful", "Build to 60 seconds"),
        e("Wrist Roller", .forearms, .bodyweight, "Roll a weight up and down on a rope.",
          "Arms straight out in front", "Both directions"),
    ]

    static let quads: [ExerciseDefinition] = [
        e("Back Squat", .quads, .barbell, "High- or low-bar squat; the foundational lower-body lift.",
          "Brace before you descend", "Knees track over toes", "Depth: hip crease below the knee if mobility allows", "Drive the floor away"),
        e("Front Squat", .quads, .barbell, "Bar on the front delts; very quad-dominant and upright.",
          "Elbows high the whole way", "Sit straight down between the heels"),
        e("Leg Press", .quads, .machine, "Machine compound leg press.",
          "Keep hips planted", "Track knees over toes", "Don't lock the knees at the top"),
        e("Hack Squat", .quads, .machine, "Angled machine squat; heavy quad loading with back support.",
          "Feet lower on the platform for more quads", "Full depth if the knees allow"),
        e("Leg Extension", .quads, .machine, "Machine quadriceps isolation.",
          "Move with control", "Pause at the top", "Pad just above the ankle"),
        e("Bulgarian Split Squat", .quads, .dumbbell, "Rear-foot-elevated split squat.",
          "Front shin roughly vertical", "Torso upright for quads, leaned for glutes", "Back foot is for balance only"),
        e("Goblet Squat", .quads, .dumbbell, "Squat holding one dumbbell at the chest.",
          "Elbows inside the knees at the bottom", "Great for learning squat depth"),
        e("Walking Lunge", .quads, .dumbbell, "Alternating forward lunges.",
          "Long stride, back knee toward the floor", "Push through the front heel"),
        e("Reverse Lunge", .quads, .dumbbell, "Step back into a lunge; easier on the knees.",
          "Step back far enough to keep the front shin vertical", "Drive up through the front foot"),
        e("Step-Up", .quads, .dumbbell, "Step onto a box, driving through the top leg.",
          "Don't push off the bottom foot", "Box at knee height"),
        e("Sissy Squat", .quads, .bodyweight, "Knees-forward squat for the rectus femoris.",
          "Hold something for balance", "Lean back as knees travel forward"),
        e("Pistol Squat", .quads, .bodyweight, "Single-leg squat to full depth.",
          "Hold a counterweight in front to balance", "Work up to it with a box behind you"),
        e("Smith Machine Squat", .quads, .smithMachine, "Fixed-path squat.",
          "Feet slightly in front of the bar", "Control the bottom"),
        e("Belt Squat", .quads, .machine, "Squat loaded at the hips; spares the spine.",
          "Stand tall, sit between the legs", "Great high-rep option"),
        e("Zercher Squat", .quads, .barbell, "Bar in the crook of the elbows; upright and demanding.",
          "Pad the bar", "Keep elbows tucked"),
        e("Jump Squat", .quads, .bodyweight, "Explosive squat for power.",
          "Land softly, absorb through the hips", "Low reps, full effort"),
        e("Wall Sit", .quads, .bodyweight, "Isometric hold with the back against a wall.",
          "Thighs parallel to the floor", "Hold for time"),
    ]

    static let hamstrings: [ExerciseDefinition] = [
        e("Romanian Deadlift", .hamstrings, .barbell, "Hip hinge for hamstrings and glutes.",
          "Push hips back", "Keep the bar close", "Soft knees, flat back", "Stop when the hamstrings say stop"),
        e("Dumbbell Romanian Deadlift", .hamstrings, .dumbbell, "RDL with dumbbells at the sides.",
          "Weights slide down the thighs", "Feel the stretch, then drive the hips forward"),
        e("Single-Leg Romanian Deadlift", .hamstrings, .dumbbell, "One-leg hinge; balance and hamstrings.",
          "Hips square to the floor", "Reach the free leg straight back"),
        e("Stiff-Leg Deadlift", .hamstrings, .barbell, "Straighter-leg hinge for more hamstring stretch.",
          "Only as deep as a flat back allows", "Legs nearly straight, not locked"),
        e("Hamstring Curl", .hamstrings, .machine, "Knee-flexion hamstring exercise.",
          "Avoid lifting hips", "Squeeze at full flexion", "Slow on the way back"),
        e("Seated Leg Curl", .hamstrings, .machine, "Curl seated; longer hamstring length under load.",
          "Thigh pad snug", "Full extension at the start"),
        e("Nordic Curl", .hamstrings, .bodyweight, "Eccentric-focused kneeling curl; very demanding.",
          "Anchor the ankles", "Lower as slowly as possible", "Push up with hands to reset if needed"),
        e("Glute-Ham Raise", .hamstrings, .machine, "GHD hip and knee extension together.",
          "Keep hips extended throughout", "Toes pressed into the plate"),
        e("Good Morning", .hamstrings, .barbell, "Bar-on-back hinge.",
          "Light weight, perfect form", "Soft knees, flat back", "Hinge until the torso is near-parallel"),
        e("Cable Pull-Through", .hamstrings, .cable, "Hinge with a rope between the legs.",
          "Face away from the machine", "Squeeze the glutes at the top"),
        e("Swiss Ball Leg Curl", .hamstrings, .bodyweight, "Curl the ball in with the heels from a bridge.",
          "Hips stay up the whole time", "Slow both directions"),
        e("Kettlebell Romanian Deadlift", .hamstrings, .kettlebell, "RDL with a kettlebell between the feet.",
          "Bell stays close to the shins", "Long spine"),
    ]

    static let glutes: [ExerciseDefinition] = [
        e("Hip Thrust", .glutes, .barbell, "Glute-focused hip extension.",
          "Keep ribs stacked", "Pause at full extension", "Chin tucked, eyes forward", "Shins vertical at the top"),
        e("Dumbbell Hip Thrust", .glutes, .dumbbell, "Hip thrust with a dumbbell across the hips.",
          "Same setup as the barbell version", "Good for higher reps"),
        e("Glute Bridge", .glutes, .bodyweight, "Floor bridge; the entry point to the hip thrust.",
          "Drive through the heels", "Squeeze at the top for a beat"),
        e("Single-Leg Glute Bridge", .glutes, .bodyweight, "Bridge on one leg.",
          "Keep hips level", "Other knee to the chest or leg straight"),
        e("Hip Abduction", .glutes, .machine, "Machine glute medius exercise.",
          "Control the return", "Lean forward slightly for more glute", "Pause at the widest point"),
        e("Cable Kickback", .glutes, .cable, "Straight-leg extension behind you against a cable.",
          "Hinge slightly forward", "Squeeze at the back, don't arch the spine"),
        e("Cable Hip Abduction", .glutes, .cable, "Standing abduction with an ankle cuff.",
          "Stand tall, hold the machine", "Small, controlled range"),
        e("Sumo Squat", .glutes, .dumbbell, "Wide-stance squat holding one dumbbell.",
          "Toes out, knees out", "Sit straight down"),
        e("Curtsy Lunge", .glutes, .dumbbell, "Cross-behind lunge for glute medius.",
          "Step behind and across", "Keep the front knee tracking over the toes"),
        e("Frog Pump", .glutes, .bodyweight, "Bridge with soles together; high-rep glute pump.",
          "Feet together, knees wide", "Fast, short reps"),
        e("Banded Lateral Walk", .glutes, .band, "Side steps against a band above the knees.",
          "Quarter-squat stance", "Keep tension on the band the whole time"),
        e("Clamshell", .glutes, .band, "Side-lying abduction with a band.",
          "Feet together, open the knees", "Don't roll the hips back"),
        e("Banded Glute Bridge", .glutes, .band, "Bridge with a band above the knees.",
          "Push the knees out into the band", "Squeeze the top"),
        e("Kettlebell Sumo Deadlift", .glutes, .kettlebell, "Wide-stance pull with a kettlebell.",
          "Bell between the feet", "Drive the hips through"),
        e("Reverse Hyperextension", .glutes, .machine, "Legs swing up behind on a reverse hyper bench.",
          "Squeeze the glutes at the top", "Control the swing back"),
        e("Smith Machine Hip Thrust", .glutes, .smithMachine, "Hip thrust on a fixed bar path.",
          "Bar padded, same hinge as the barbell version", "Full lockout"),
    ]

    static let calves: [ExerciseDefinition] = [
        e("Standing Calf Raise", .calves, .machine, "Straight-leg raise for the gastrocnemius.",
          "Full stretch at the bottom", "Pause at the top", "Don't bounce"),
        e("Seated Calf Raise", .calves, .machine, "Bent-knee raise for the soleus.",
          "Pad on the lower thigh", "Slow tempo"),
        e("Leg Press Calf Raise", .calves, .machine, "Calf raise on the leg press platform.",
          "Toes on the edge, heels hanging", "Keep the knees soft but not bending"),
        e("Single-Leg Calf Raise", .calves, .dumbbell, "One-leg raise on a step.",
          "Hold a dumbbell on the working side", "Full range"),
        e("Donkey Calf Raise", .calves, .machine, "Bent-over raise; strong gastrocnemius stretch.",
          "Hips back, legs straight", "Deep stretch each rep"),
        e("Bodyweight Calf Raise", .calves, .bodyweight, "Raises on a step with no load.",
          "High reps", "Pause at the top and the bottom"),
    ]

    static let core: [ExerciseDefinition] = [
        e("Plank", .core, .bodyweight, "Isometric trunk exercise.",
          "Squeeze glutes", "Breathe steadily", "Elbows under shoulders, body in a line"),
        e("Side Plank", .core, .bodyweight, "Lateral plank for the obliques.",
          "Hips high and stacked", "Elbow under the shoulder"),
        e("Dead Bug", .core, .bodyweight, "Opposite arm and leg extend while the low back stays down.",
          "Press the lower back into the floor", "Exhale as you extend"),
        e("Bird Dog", .core, .bodyweight, "Opposite arm and leg from all fours.",
          "Don't let the hips rotate", "Reach long, pause"),
        e("Hanging Leg Raise", .core, .bodyweight, "Raise straight legs from a bar hang.",
          "Tilt the pelvis — don't just swing the legs", "Bend the knees to scale"),
        e("Hanging Knee Raise", .core, .bodyweight, "Knees to the chest from a hang.",
          "Curl the pelvis up at the top", "Slow lower"),
        e("Cable Crunch", .core, .cable, "Kneeling crunch with a rope.",
          "Hips stay still — crunch with the spine", "Elbows toward the knees"),
        e("Ab Wheel Rollout", .core, .bodyweight, "Roll out from the knees and pull back.",
          "Don't let the hips sag", "Shorten the range to scale"),
        e("Pallof Press", .core, .cable, "Anti-rotation press-out from a cable.",
          "Stand side-on to the cable", "Press out and hold, resist the twist"),
        e("Russian Twist", .core, .dumbbell, "Seated rotation with a weight.",
          "Feet up for harder", "Rotate the torso, not just the arms"),
        e("Crunch", .core, .bodyweight, "Short-range spinal flexion.",
          "Chin off the chest", "Exhale at the top"),
        e("Reverse Crunch", .core, .bodyweight, "Pelvis lifts toward the chest.",
          "Lift hips off the floor", "Control the lower"),
        e("Bicycle Crunch", .core, .bodyweight, "Alternating elbow-to-knee.",
          "Slow and controlled", "Extend the straight leg fully"),
        e("Mountain Climber", .core, .bodyweight, "Alternating knee drives from a push-up position.",
          "Hips level", "Fast for conditioning, slow for control"),
        e("Hollow Body Hold", .core, .bodyweight, "Gymnastics hold; lower back pressed down.",
          "Arms and legs long, lower back flat", "Bend the knees to scale"),
        e("Toes to Bar", .core, .bodyweight, "Hanging raise touching the feet to the bar.",
          "Lats engaged, swing controlled", "Scale with knee raises"),
        e("Weighted Plank", .core, .bodyweight, "Plank with a plate on the back.",
          "Same standards as the plank", "Have someone place the plate"),
        e("Farmer's Walk", .core, .kettlebell, "Loaded carry; core, grip, posture.",
          "Stand tall, don't lean", "Walk for distance"),
        e("Suitcase Carry", .core, .kettlebell, "One-sided carry; anti-lateral-flexion.",
          "Don't lean away from the weight", "Switch sides"),
        e("Machine Crunch", .core, .machine, "Seated crunch machine.",
          "Crunch the ribs toward the hips", "Control the return"),
        e("Decline Sit-Up", .core, .bodyweight, "Sit-up on a decline bench.",
          "Hold a plate to progress", "Lower slowly"),
        e("Windshield Wiper", .core, .bodyweight, "Hanging leg rotation side to side.",
          "Legs up first, then rotate", "Advanced"),
    ]

    static let fullBody: [ExerciseDefinition] = [
        e("Clean and Press", .fullBody, .barbell, "Clean the bar to the shoulders, press overhead.",
          "Explosive hip drive", "Reset each rep"),
        e("Power Clean", .fullBody, .barbell, "Explosive pull from the floor caught at the shoulders.",
          "Bar stays close", "Triple extension, then pull under", "Technique first"),
        e("Push Press", .fullBody, .barbell, "Overhead press with a leg drive.",
          "Quarter dip, drive straight up", "Finish the press with the shoulders"),
        e("Thruster", .fullBody, .barbell, "Front squat into an overhead press.",
          "One fluid movement", "Breathe at the top"),
        e("Snatch", .fullBody, .barbell, "Floor to overhead in one movement.",
          "Wide grip", "Learn with a coach or empty bar"),
        e("Kettlebell Clean", .fullBody, .kettlebell, "Bell from the swing to the rack position.",
          "Keep the bell close, tame the arc", "Soft catch"),
        e("Kettlebell Snatch", .fullBody, .kettlebell, "Bell from swing to overhead.",
          "Punch through at the top", "Control the descent"),
        e("Turkish Get-Up", .fullBody, .kettlebell, "Floor to standing with a bell held overhead.",
          "Eyes on the bell", "Slow — each step is a position"),
        e("Burpee", .fullBody, .bodyweight, "Drop, push-up, jump.",
          "Chest to the floor", "Full extension on the jump"),
        e("Dumbbell Thruster", .fullBody, .dumbbell, "Squat to press with dumbbells.",
          "Press out of the squat", "Lockout overhead"),
        e("Man Maker", .fullBody, .dumbbell, "Push-up, rows, clean, press — one rep.",
          "Slow down, hit every position", "Light dumbbells"),
        e("Sled Push", .fullBody, .machine, "Push a loaded sled.",
          "Low body angle, drive with the legs", "Distance or time"),
        e("Sled Pull", .fullBody, .machine, "Drag a sled backward or forward.",
          "Backward for quads", "Steady pace"),
        e("Battle Ropes", .fullBody, .bodyweight, "Alternating waves for conditioning.",
          "Quarter squat, brace", "Intervals"),
        e("Box Jump", .fullBody, .bodyweight, "Jump onto a box.",
          "Land soft with the whole foot", "Step down, don't jump down"),
        e("Bear Crawl", .fullBody, .bodyweight, "Crawl with knees an inch off the floor.",
          "Back flat, hips low", "Opposite hand and foot"),
        e("Wall Ball", .fullBody, .bodyweight, "Squat and throw a medicine ball to a target.",
          "Full squat", "Catch and go"),
        e("Kettlebell Goblet Squat", .fullBody, .kettlebell, "Squat holding the bell at the chest.",
          "Elbows inside the knees", "Chest up"),
    ]

    public static let all: [ExerciseDefinition] =
        chest + back + shoulders + biceps + triceps + forearms + quads + hamstrings + glutes + calves + core + fullBody

    public static let byName: [String: ExerciseDefinition] = {
        var map = [String: ExerciseDefinition]()
        for definition in all { map[definition.name] = definition }
        return map
    }()

    public static func definition(named name: String) -> ExerciseDefinition? { byName[name] }

    public static func exercises(in group: MuscleGroup) -> [ExerciseDefinition] { all.filter { $0.muscleGroup == group } }
}
