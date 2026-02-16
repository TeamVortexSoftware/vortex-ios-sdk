Hey team! 👋 We've shipped some updates to the Vortex SDK that require changes on your side. Here's what you need to know and do:

---

*1️⃣ `internalId` → `userId` (breaking change)*

We've renamed the `internalId` property to `userId` on all contact types:
• `FindFriendsContact`
• `InvitationSuggestionContact`
• `SearchBoxContact`

_Why?_ The term `internalId` was ambiguous — it could be interpreted as an internal SDK identifier rather than your platform's user ID. Since this field represents the user's identity in *your* system (the UUID you use to identify users), `userId` is clearer and more intuitive. It also aligns with the `userId` field on `IncomingInvitationItem` and `OutgoingInvitationItem`, which is used for deduplication.

_Before:_
```
FindFriendsContact(internalId: "abc-123", name: "John Doe")
```
_After:_
```
FindFriendsContact(userId: "abc-123", name: "John Doe")
```

The API payload sent to the Vortex backend is unchanged (`internalId` internally) — only the SDK-facing property name changed.

---

*2️⃣ Metadata on contacts*

All contact types (`FindFriendsContact`, `InvitationSuggestionContact`, `SearchBoxContact`) now accept an optional `metadata` dictionary. This metadata is included in the invitation payload sent to the Vortex API and stored server-side.

You should include BFF IDs in the metadata for every contact you pass to Find Friends, Invitation Suggestions, and Search Box:

```
FindFriendsContact(
    userId: "abc-123",
    name: "John Doe",
    subtitle: "@johndoe",
    metadata: [
        "inviter_bff_id": "@current_user_bff_id",
        "invitee_bff_id": "@johndoe"
    ]
)
```

• `inviter_bff_id` — the BFF ID of the currently logged-in user (the one sending the invitation)
• `invitee_bff_id` — the BFF ID of the person being invited

This metadata flows end-to-end: contact → invitation creation → stored on Vortex server → returned when fetching invitations later.

---

*3️⃣ Incoming Invitations: `subtitle` removed, `getSubtitle` callback added*

The `subtitle` property has been *removed* from `IncomingInvitationItem`. Instead, you now provide a `getSubtitle` callback on `IncomingInvitationsConfig` that computes the subtitle from the invitation's metadata.

_Before:_
```
IncomingInvitationItem(id: "inv-1", name: "John Doe", subtitle: "@johndoe")
```

_After:_
```
IncomingInvitationsConfig(
    internalInvitations: [
        IncomingInvitationItem(
            id: "inv-1",
            name: "John Doe",
            userId: "abc-123",
            metadata: ["inviter_bff_id": "@johndoe"]
        )
    ],
    onAccept: { invitation in return true },
    onDelete: { invitation in return true },
    getSubtitle: { invitation in
        return invitation.metadata?["inviter_bff_id"] as? String
    }
)
```

If `getSubtitle` is not provided, no subtitle is rendered.

---

*4️⃣ Outgoing Invitations: same pattern*

Same change — `subtitle` removed from `OutgoingInvitationItem`, replaced by `getSubtitle` callback on `OutgoingInvitationsConfig`:

```
OutgoingInvitationsConfig(
    internalInvitations: [
        OutgoingInvitationItem(
            id: "inv-2",
            name: "Jane Smith",
            userId: "def-456",
            metadata: ["invitee_bff_id": "@janesmith"]
        )
    ],
    onCancel: { invitation in return true },
    getSubtitle: { invitation in
        return invitation.metadata?["invitee_bff_id"] as? String
    }
)
```

---

*5️⃣ Deduplication by `userId`*

If you provide internal invitations (via `internalInvitations` array) alongside the ones fetched from the Vortex API, the SDK now deduplicates by `userId`:

• *Incoming Invitations:* If an internal invitation and a Vortex API invitation share the same `userId`, the API one is kept (it supports server-side accept/delete). The `userId` maps to `creatorId` on the Vortex side.
• *Outgoing Invitations:* Same logic — `userId` maps to `targetValue` (the invitation target). The API invitation wins.

Make sure every invitation item you pass has a `userId` set for deduplication to work correctly. Items without a `userId` are never considered duplicates.

*Important:* Because the `onAccept`/`onDelete` (Incoming) and `onCancel` (Outgoing) callbacks are called *before* the SDK takes action, you have the opportunity to handle deduplicated invitations at that moment. For example, if a Vortex API invitation replaced one of your internal invitations during deduplication, your callback will still fire when the user acts on it — giving you a chance to update your own records accordingly.

---

*6️⃣ `onAccept` / `onDelete` / `onCancel` callbacks*

These callbacks are called *before* the Vortex API call as a gate:
• Return `true` → SDK proceeds with the API call (for Vortex invitations) or removes from list (for internal invitations)
• Return `false` → action is cancelled, invitation stays in the list

For internal invitations (`isVortexInvitation == false`), handle the accept/delete/cancel logic in your callback, then return `true` to remove from the list.

---

*Summary of what you need to do:*

✅ Rename `internalId` → `userId` on all contact types
✅ Add `metadata` with `inviter_bff_id` and `invitee_bff_id` to all contacts passed to Find Friends, Invitation Suggestions, and Search Box
✅ Add `metadata` with the appropriate BFF ID to any internal `IncomingInvitationItem` and `OutgoingInvitationItem` you provide
✅ Remove `subtitle` from `IncomingInvitationItem` and `OutgoingInvitationItem`
✅ Implement `getSubtitle` callbacks on `IncomingInvitationsConfig` and `OutgoingInvitationsConfig` to extract BFF IDs from metadata
✅ Set `userId` on all invitation items for deduplication

Let us know if you have any questions! 🚀
