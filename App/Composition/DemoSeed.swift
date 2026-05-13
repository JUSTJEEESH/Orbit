#if DEBUG
import Foundation
import OrbitDomain
import OrbitKit

/// One-shot programmatic seeder for screenshot prep. Bypasses voice
/// recording entirely — every memory's content (including voice-note
/// transcripts) is hardcoded, so simulator-flaky speech recognition
/// is never in the loop.
///
/// Wrapped in `#if DEBUG` so the symbol doesn't ship in Release
/// builds. The Settings → "Seed demo data" affordance that triggers
/// this method is also DEBUG-only.
///
/// Run once from a fresh install, then take screenshots. The seeder
/// is idempotent-friendly: tapping it twice produces duplicates,
/// which you can either delete or live with (the timeline reads
/// fine).
extension AppEnvironment {
    @MainActor
    func seedDemoData() async {
        // Each memory below is created via the production
        // `captureMemory` use case, then handed to
        // `scheduleEnrichment` so the AI pipeline fills in tags,
        // summaries, and categories exactly the way it would for a
        // real capture.
        var createdIDs: [UUID] = []

        // Demo memories are deliberately spread across the last ~5 weeks
        // so the Home tab's "Worth revisiting" surface has variety to
        // anchor on (engine requires anchor ≥7 days old, max 60). The
        // dates also produce realistic Timeline scrolling instead of
        // every card stacked on one day.
        let daysAgo: (Int) -> Date = { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: self.clock.now())
                ?? self.clock.now()
        }

        // 1 — Voice: bookshop in Roatan (22 days ago — anchor candidate,
        // rich entity content, threads into the reading cluster: #3, #8, #9)
        await seedVoiceMemo(
            transcript: """
            Note to self about that bookshop in Roatan — the one with \
            the iron spiral staircase up to the second floor. The owner's \
            name escapes me, I want to say Mateo or maybe Mateusz, \
            something starting with M. He pulled three novels off the \
            shelf for me and made me coffee in this little Bialetti while \
            we talked. The one he kept coming back to was an Argentinian \
            writer, I think César Aira — a thin paperback with a yellow \
            cover, almost like a pamphlet. I promised him I'd order it \
            when I got home and I have not. The shop is two blocks off \
            the main square, painted a deep teal, and there's a tabby \
            cat that sleeps on the philosophy table.
            """,
            duration: 42,
            createdAt: daysAgo(22),
            into: &createdIDs
        )

        // 2 — Text: talk opener (5 days ago, recent, threads to #3 via talk-prep)
        await seedText("""
            Idea for opening the talk next month — start with the \
            Kandinsky line about the soul being a piano with many \
            strings, and the artist as the hand that plays it. Bridge to \
            Brian Eno's idea of "scenius" — the credit for good work \
            doesn't belong to one person, it belongs to a community, an \
            ecology. The whole point of the talk is that the work happens \
            at the intersection, not the peak.

            Maybe close with the Anne Lamott line about radio towers — \
            that we're all just transmitting and receiving, and the worst \
            thing we can do is mistake our station for the signal itself.

            I should ask Maria if she'll do the intro. She owes me one.
            """,
            createdAt: daysAgo(5),
            into: &createdIDs)

        // 3 — Link: New Yorker (31 days ago, reading + talk-prep cluster)
        await seedLink(
            urlString: "https://www.newyorker.com/magazine/2024/02/12/the-new-economics-of-the-arts",
            title: "The New Economics of the Arts",
            summary: """
            Read this twice this week, both times angry then thoughtful. \
            The argument I keep returning to is that subsidy isn't \
            generosity, it's infrastructure — the same way roads are, \
            the same way libraries are. Save for the talk.
            """,
            createdAt: daysAgo(31),
            into: &createdIDs
        )

        // 4 — Voice: Pamela / restaurant (10 days ago — Pamela entity)
        await seedVoiceMemo(
            transcript: """
            OK so Pamela called this morning — she finally tried that new \
            restaurant in the Castro everyone's been talking about. I \
            think it's called Florín, with the umlaut maybe, I'm not \
            sure. She went with her sister last Thursday and had the lamb \
            tasting menu, said the second course was the single best \
            thing she's eaten this year. Three different cuts of lamb, \
            all from the same farm in Sonoma, with this charred fennel \
            thing on the side that she said she still thinks about. We \
            should try to get a reservation for next weekend if Daniel \
            and I can find a sitter. She said book three weeks out, they \
            don't take walk-ins.
            """,
            duration: 45,
            createdAt: daysAgo(10),
            into: &createdIDs
        )

        // 5 — Text: Dr. Tanaka follow-up (35 days ago, anchors health cluster: #7)
        await seedText("""
            Reminder to myself: I should write to Dr. Tanaka about the \
            follow-up in March. The lab results from October were better \
            than expected — cholesterol came down 28 points, A1C is back \
            in normal range for the first time in two years. He asked me \
            to send him a quick paragraph on how the new routine is going \
            before we book the next physical. Just a few sentences, no \
            need to be fancy.

            Things to mention: the running is consistent now (four days a \
            week since November), I'm sleeping seven hours instead of \
            five, the afternoon brain fog is gone. Don't mention the \
            coffee.
            """,
            createdAt: daysAgo(35),
            into: &createdIDs)

        // 6 — Text: gratitude triple (1 day ago — yesterday)
        await seedText("""
            Three things I'm grateful for today —

            1. The afternoon light on the kitchen counter at exactly 4 \
            PM, when it hits the marble at the right angle and the whole \
            room goes amber for about twenty minutes. I forgot how much I \
            missed it during the renovation last year.

            2. That my sister called just to say hi — no agenda, no \
            logistics, no asking for anything. She just wanted to know \
            how I was doing. We talked for an hour about nothing \
            important and I felt like a whole person again afterward.

            3. Coffee that wasn't even particularly good — the gas \
            station kind, in a styrofoam cup — but felt earned because \
            it was the first thing after the morning run and I drank it \
            sitting on the trunk of the car while the sun came up.
            """,
            createdAt: daysAgo(1),
            into: &createdIDs)

        // 7 — Voice: river run (18 days ago, health cluster with #5)
        await seedVoiceMemo(
            transcript: """
            Just finished the river loop, second time this week — six \
            and a half kilometers, came in just under thirty minutes for \
            the first time since the surgery last spring. The herons are \
            back at the bend by the old pump house, three of them this \
            morning, standing like statues, and the willow has started to \
            bud out which means we're maybe two weeks from the bay being \
            warm enough to swim. Felt good in my knees, no twinges, \
            which has not been the case for most of February. I think \
            the new shoes are working.
            """,
            duration: 35,
            createdAt: daysAgo(18),
            into: &createdIDs
        )

        // 8 — Link: Every essay (14 days ago, reading cluster)
        await seedLink(
            urlString: "https://every.to/p/the-end-of-organizing",
            title: "The End of Organizing",
            summary: """
            Saving this for later — Olivia mentioned it on the call last \
            night, said it changed how she thinks about deadlines and \
            to-do lists. The premise is that organization is a coping \
            mechanism for anxiety more than a productivity strategy. \
            Worth thirty minutes when I'm not exhausted.
            """,
            createdAt: daysAgo(14),
            into: &createdIDs
        )

        // 9 — Text: want to read (45 days ago, reading + Pamela cluster)
        await seedText("""
            I want to read "The Master and Margarita" — Pamela has \
            mentioned it twice now in different contexts, once when we \
            were talking about Bulgakov in general and once when she was \
            describing the cat that lives in the apartment downstairs \
            from her. The translation she said matters is the Pevear and \
            Volokhonsky one, not the older one with the simpler prose. \
            She said the cat — Behemoth, in the novel — is the best \
            character in any novel she's read.

            I trust her completely on this. Add to the list. Borrow \
            from the library first, buy a copy if I love it.
            """,
            createdAt: daysAgo(45),
            into: &createdIDs)

        // 10 — Letter to future self (sealed)
        await seedLetter()

        // Manual tasks — three on top of what the AI will suggest from
        // the memories above.
        await seedTask(
            title: "Call dentist about Friday appointment",
            notes: """
            Confirm the 2:30 slot still works. Need to ask about the \
            crown estimate too — Dr. Patel mentioned insurance would \
            cover roughly 70%, but I want to see the actual number before \
            saying yes.
            """,
            dueOffsetDays: 1
        )
        await seedTask(
            title: "Pick up dry cleaning",
            notes: """
            Two shirts and the navy suit at the place on 4th. They \
            close at 6 on Wednesdays. Pay cash if they have it — they \
            prefer it and there's a small discount.
            """,
            dueOffsetDays: 0
        )
        await seedTask(
            title: "Book flights for spring trip",
            notes: """
            Daniel and Maria both want to come now, so we're looking at \
            four tickets, not two. Aim for the second week of May, \
            ideally landing on the 11th. Daniel needs to be back by the \
            19th for the conference. Aim for under $600 a ticket if we \
            go through SFO.
            """,
            dueOffsetDays: 7
        )

        memoriesDidChange()

        OrbitLog.app.notice("Demo data seeded: \(createdIDs.count, privacy: .public) memories + 3 manual tasks.")
    }

    // MARK: - Helpers

    @MainActor
    private func seedText(_ body: String, createdAt: Date? = nil, into createdIDs: inout [UUID]) async {
        do {
            let memory = try await captureMemory(content: .text(body), createdAt: createdAt)
            scheduleEnrichment(for: memory.id)
            createdIDs.append(memory.id)
        } catch {
            OrbitLog.app.error("Demo seed text failed: \(String(describing: error), privacy: .public)")
        }
    }

    @MainActor
    private func seedVoiceMemo(transcript: String, duration: TimeInterval, createdAt: Date? = nil, into createdIDs: inout [UUID]) async {
        do {
            let memory = try await captureMemory(
                content: .voiceNote(transcript: transcript, duration: duration),
                createdAt: createdAt
            )
            scheduleEnrichment(for: memory.id)
            createdIDs.append(memory.id)
        } catch {
            OrbitLog.app.error("Demo seed voice failed: \(String(describing: error), privacy: .public)")
        }
    }

    @MainActor
    private func seedLink(urlString: String, title: String, summary: String, createdAt: Date? = nil, into createdIDs: inout [UUID]) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let memory = try await captureMemory(
                content: .link(url: url, title: title, summary: summary),
                createdAt: createdAt
            )
            scheduleEnrichment(for: memory.id)
            createdIDs.append(memory.id)
        } catch {
            OrbitLog.app.error("Demo seed link failed: \(String(describing: error), privacy: .public)")
        }
    }

    @MainActor
    private func seedLetter() async {
        let body = """
        Dear me, six months from now —

        I started something this month that I wasn't sure I could finish, \
        and by the time you read this you'll either know how it went or \
        you'll be in the middle of finding out. Either way, I'm writing \
        to you now because the version of me that started it deserves to \
        be remembered by the version of you that knows the ending.

        Some specifics for context. I'm sitting in the kitchen, it's \
        late, there's half a mug of cold tea next to the laptop and \
        Chispita is asleep under the table. The talk is in three weeks. \
        The annual physical is in March. Daniel's birthday is in April \
        and I haven't planned anything yet but I will. Maria called \
        yesterday about the trip and we agreed to push it to June, so \
        don't beat yourself up about not having gone in May.

        What I want you to know — what I'm telling you, future self — \
        is that the part where you tried, even if it didn't work out, \
        is the part that matters. I'm proud of that part. Be proud of \
        that part. Whatever happened next, you didn't make it not have \
        happened. You started. That counts.

        Be gentle with yourself. Eat something. Call your sister.

        — me, today.
        """
        let surfaceDate = Calendar.current.date(byAdding: .month, value: 6, to: clock.now())
        do {
            let memory = try await captureMemory(
                content: .text(body),
                surfaceDate: surfaceDate,
                isLetter: true
            )
            scheduleSealedDeliveryIfNeeded(for: memory.id)
        } catch {
            OrbitLog.app.error("Demo seed letter failed: \(String(describing: error), privacy: .public)")
        }
    }

    @MainActor
    private func seedTask(title: String, notes: String, dueOffsetDays: Int) async {
        let due = Calendar.current.date(byAdding: .day, value: dueOffsetDays, to: clock.now())
        let task = MemoryTask(
            title: title,
            notes: notes,
            dueDate: due,
            createdAt: clock.now()
        )
        do {
            try await tasks.save(task)
        } catch {
            OrbitLog.app.error("Demo seed task failed: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif
