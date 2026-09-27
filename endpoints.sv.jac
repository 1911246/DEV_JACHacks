"""FreeBuff - server-side data model and API endpoints.

Every user type (donor, organization, recipient) gets an isolated graph root
at login. Nodes a user creates live under their own root; anything that must
cross the isolation boundary is opened with grant(). The public community
feed is assembled by scanning allroots() for APPROVED donations that were
granted at publish time.

The workflow, end to end:
    Donor: AnalyzeFoodPhoto (vision AI) -> SubmitDonation (PENDING)
    Org:   ListIncomingRequests -> ApproveDonation / RejectDonation
    All:   ListAvailableFood (public, approved only)
    Recipient: ClaimFood (atomic servings check) -> ListMyReservations
"""

import from datetime { datetime, date }
import random;
import uuid;

include lib;

# ------------------------------------------------------------ data model --

"""Application roles."""
enum Role {
    DONOR,
    ORGANIZATION,
    RECIPIENT
}

"""User profile stored on the user's own root; role drives authorization."""
node Profile {
    has role: str = "RECIPIENT",
        display_name: str = "",
        created_at: str = "";
}

"""A participating drop-off / pickup organization."""
node Organization {
    has org_type: str = "",
        contact_name: str = "",
        phone: str = "",
        address: str = "",
        pickup_hours: str = "",
        accepted_food_types: str = "",
        refrigeration: bool = False,
        storage: str = "",
        description: str = "",
        created_at: str = "";
}

"""One donation submission. AI fields are estimates; the rest is human data."""
node Donation {
    has org_id: str = "",
        food_name: str = "",
        image_url: str = "",
        ai_ingredients: list[str] = [],
        ai_serving_size: str = "",
        ai_nutrition: dict = {},
        donated_servings: int = 1,
        preparation_date: str = "",
        expiration_date: str = "",
        donor_notes: str = "",
        status: str = "PENDING",
        created_at: str = "",
        approved_at: str = "",
        rejected_at: str = "",
        rejection_reason: str = "";
}

"""A confirmed hold on N servings of one donation."""
node Reservation {
    has donation_id: str = "",
        code: str = "",
        servings: int = 1,
        status: str = "RESERVED",
        reserved_at: str = "",
        picked_up_at: str = "",
        cancelled_at: str = "";
}

# ------------------------------------------------------------ helpers --
"""True when the donation's best-by date has passed."""
def is_expired(d: Donation) -> bool {
    if not d.expiration_date {
        return False;
    }
    try {
        return date.fromisoformat(d.expiration_date) < date.today();
    } except Exception {
        return False;
    }
}


"""Sum of servings held by active (RESERVED) reservations."""
def active_reserved(d: Donation) -> int {
    total: int = 0;
    target = jid(d);
    # Concurrent claims are guarded by per-node optimistic concurrency on the
    # donation + reservation writes: a losing request replays against the
    # winner's committed state, so this sum re-evaluates with fresh data.
    for r in allroots() {
        for res in [r-->][?:Reservation] {
            if res.status == "RESERVED" and res.donation_id == target {
                total += res.servings;
            }
        }
    }
    return total;
}


def available_servings(d: Donation) -> int {
    left = d.donated_servings - active_reserved(d);
    if left < 0 {
        return 0;
    }
    return left;
}


"""Friendly lifecycle status derived from dates and reservations."""
def display_status(d: Donation) -> str {
    if d.status == "APPROVED" {
        if is_expired(d) {
            return "EXPIRED";
        }
        left = available_servings(d);
        if left <= 0 {
            return "FULLY_RESERVED";
        }
        if left < d.donated_servings {
            return "PARTIALLY_RESERVED";
        }
    }
    return d.status;
}


"""Unique short reservation code like FB-1042."""
def gen_reservation_code -> str {
    taken: dict = {};
    for r in allroots() {
        for res in [r-->][?:Reservation] {
            taken[res.code] = True;
        }
    }
    attempt: int = 0;
    while attempt < 50 {
        candidate = "FB-" + str(random.randint(1000, 9999));
        if candidate not in taken {
            return candidate;
        }
        attempt += 1;
    }
    return "FB-" + uuid.uuid4().hex[0:6].upper();
}

# --------------------------------------------------------- account wiring --

"""Complete signup: profile node for this account, role from onboarding."""
walker:priv CompleteProfile {
    has role: str = "RECIPIENT",
        display_name: str = "",
        reports: list[Profile] = [];

    can create with Root entry {
        existing = [root-->][?:Profile];
        if existing {
            report existing[0];
            disengage;
        }
        role = self.role if self.role in ("DONOR", "ORGANIZATION", "RECIPIENT") else "RECIPIENT";
        p = (root ++> Profile(
            role=role,
            display_name=self.display_name,
            created_at=now_iso()
        ))[0];
        report p;
    }
}

"""Report the caller's profile (or nothing) without creating anything."""
walker:priv GetProfile {
    has reports: list[dict] = [];

    can read with Root entry {
        existing = [root-->][?:Profile];
        if existing {
            p = existing[0];
            report {
                "id": jid(p),
                "role": p.role,
                "display_name": p.display_name,
                "created_at": p.created_at
            };
        }
    }
}

# ---------------------------------------------------------- donor portal --

"""Vision AI: food photo -> ingredients + serving size + nutrition ONLY."""
walker:priv AnalyzeFoodPhoto {
    has image_data: str;

    can analyze with Root entry {
        prof = [root-->][?:Profile];
        if not prof or prof[0].role != "DONOR" {
            report {"error": "Only donor accounts can analyze food photos."};
            disengage;
        }
        try {
            image = Image(self.image_data);
            result = analyze_food_photo(
                photo_image=image,
                what="a home-cooked dish a neighbor wants to donate"
            );
            report {
                "ingredients": result.ingredients,
                "serving_size": result.serving_size,
                "nutrition": {
                    "calories": result.nutrition.calories,
                    "protein": result.nutrition.protein,
                    "carbohydrates": result.nutrition.carbohydrates,
                    "fat": result.nutrition.fat
                }
            };
        } except Exception as e {
            report {"error": f"AI analysis failed: {e}"};
        }
    }
}

"""Create a PENDING donation addressed to one organization."""
walker:priv SubmitDonation {
    has org_id: str,
        image_data: str,
        food_name: str,
        servings: int = 1,
        ai_ingredients: list[str] = [],
        ai_serving_size: str = "",
        ai_nutrition: dict = {},
        preparation_date: str = "",
        expiration_date: str = "",
        donor_notes: str = "",
        reports: list[dict] = [];

    can submit with Root entry {
        prof = [root-->][?:Profile];
        if not prof or prof[0].role != "DONOR" {
            report {"error": "Only donor accounts can submit food."};
            disengage;
        }
        if self.servings < 1 {
            report {"error": "Servings must be at least 1."};
            disengage;
        }
        org = get_node(self.org_id);
        if org is None or not isinstance(org, Organization) {
            report {"error": "Organization not found."};
            disengage;
        }
        d = (root ++> Donation(
            org_id=jid(org),
            food_name=self.food_name.strip() if self.food_name.strip() else "Home-cooked food",
            image_url=self.image_data,
            ai_ingredients=self.ai_ingredients,
            ai_serving_size=self.ai_serving_size,
            ai_nutrition=self.ai_nutrition,
            donated_servings=self.servings,
            preparation_date=self.preparation_date,
            expiration_date=self.expiration_date,
            donor_notes=self.donor_notes,
            status="PENDING",
            created_at=now_iso()
        ))[0];
        # readable cross-user so the org can review/approve and the
        # community feed can list it once approved (org linkage via org_id)
        grant(d, level=WritePerm);
        report {
            "id": jid(d),
            "food_name": d.food_name,
            "image_url": d.image_url,
            "ai_ingredients": d.ai_ingredients,
            "ai_serving_size": d.ai_serving_size,
            "ai_nutrition": d.ai_nutrition,
            "donated_servings": d.donated_servings,
            "preparation_date": d.preparation_date,
            "expiration_date": d.expiration_date,
            "donor_notes": d.donor_notes,
            "status": d.status,
            "created_at": d.created_at
        };
    }
}

"""The donor's own submission history, newest first."""
walker:priv ListMyDonations {
    has reports: list[dict] = [];

    can read with Root entry {
        mine = [root-->][?:Donation];
        for d in mine {
            report {
                "id": jid(d),
                "org_id": d.org_id,
                "food_name": d.food_name,
                "image_url": d.image_url,
                "ai_ingredients": d.ai_ingredients,
                "ai_serving_size": d.ai_serving_size,
                "ai_nutrition": d.ai_nutrition,
                "donated_servings": d.donated_servings,
                "preparation_date": d.preparation_date,
                "expiration_date": d.expiration_date,
                "donor_notes": d.donor_notes,
                "status": d.status,
                "created_at": d.created_at,
                "rejection_reason": d.rejection_reason
            };
        }
    }
}

# ------------------------------------------------------ organization side --

"""All participating organizations, for donors picking a drop-off."""
walker:pub ListOrganizations {
    has reports: list[dict] = [];

    can browse with Root entry {
        out: list[dict] = [];
        seen: dict = {};
        for r in allroots() {
            for o in [r-->][?:Organization] {
                key = jid(o);
                if key not in seen {
                    seen[key] = True;
                    out.append({
                        "id": key,
                        "name": o.contact_name,
                        "org_type": o.org_type,
                        "address": o.address,
                        "pickup_hours": o.pickup_hours,
                        "accepted_food_types": o.accepted_food_types,
                        "refrigeration": o.refrigeration,
                        "storage": o.storage,
                        "description": o.description
                    });
                }
            }
        }
        for item in out {
            report item;
        }
    }
}

"""Register an organization for the logged-in account."""
walker:priv RegisterOrganization {
    has org_name: str,
        org_type: str = "",
        contact_name: str = "",
        phone: str = "",
        address: str = "",
        pickup_hours: str = "",
        accepted_food_types: str = "",
        refrigeration: bool = False,
        storage: str = "",
        description: str = "",
        reports: list[dict] = [];

    can register with Root entry {
        prof = [root-->][?:Profile];
        if not prof or prof[0].role != "ORGANIZATION" {
            report {"error": "Only organization accounts can register an organization."};
            disengage;
        }
        if not self.org_name.strip() {
            report {"error": "Organization name is required."};
            disengage;
        }
        existing = [root-->][?:Organization];
        if existing {
            report {"error": "This account already has an organization."};
            disengage;
        }
        o = (root ++> Organization(
            org_type=self.org_type,
            contact_name=self.org_name.strip(),
            phone=self.phone,
            address=self.address,
            pickup_hours=self.pickup_hours,
            accepted_food_types=self.accepted_food_types,
            refrigeration=self.refrigeration,
            storage=self.storage,
            description=self.description,
            created_at=now_iso()
        ))[0];
        # open to every logged-in user so donors can discover it when
        # choosing where to send food
        grant(o, level=ReadPerm);
        report {"created": jid(o), "name": o.contact_name};
    }
}

"""The logged-in organization's own record."""
walker:priv GetMyOrganization {
    has reports: list[dict] = [];

    can read with Root entry {
        for o in [root-->][?:Organization] {
            report {
                "id": jid(o),
                "contact_name": o.contact_name,
                "org_type": o.org_type,
                "phone": o.phone,
                "address": o.address,
                "pickup_hours": o.pickup_hours,
                "accepted_food_types": o.accepted_food_types,
                "refrigeration": o.refrigeration,
                "storage": o.storage,
                "description": o.description
            };
        }
    }
}

"""Incoming PENDING submissions addressed to the caller's organization."""
walker:priv ListIncomingRequests {
    has reports: list[dict] = [];

    can read with Root entry {
        mine = [root-->][?:Organization];
        if not mine {
            report {"error": "No organization registered for this account."};
            disengage;
        }
        org = mine[0];
        org_id = jid(org);
        seen: dict = {};
        for r in allroots() {
            for d in [r-->][?:Donation] {
                if jid(d) in seen {
                    continue;
                }
                seen[jid(d)] = True;
                if d.status != "PENDING" {
                    continue;
                }
                # donations store org_id; the org's own node is readable
                # cross-user thanks to its ReadPerm grant
                if d.org_id != org_id {
                    continue;
                }
                report {
                    "id": jid(d),
                    "food_name": d.food_name,
                    "image_url": d.image_url,
                    "ai_ingredients": d.ai_ingredients,
                    "ai_serving_size": d.ai_serving_size,
                    "ai_nutrition": d.ai_nutrition,
                    "donated_servings": d.donated_servings,
                    "preparation_date": d.preparation_date,
                    "expiration_date": d.expiration_date,
                    "donor_notes": d.donor_notes,
                    "status": d.status,
                    "created_at": d.created_at
                };
            }
        }
    }
}

"""Approve a submission: it becomes an active public listing."""
walker:priv ApproveDonation {
    has donation_id: str,
        reports: list[dict] = [];

    can approve with Root entry {
        mine = [root-->][?:Organization];
        if not mine {
            report {"error": "No organization registered for this account."};
            disengage;
        }
        org = mine[0];
        d = get_node(self.donation_id);
        if d is None or not isinstance(d, Donation) {
            report {"error": "Submission not found."};
            disengage;
        }
        if d.org_id != jid(org) {
            report {"error": "This submission was not sent to your organization."};
            disengage;
        }
        if d.status != "PENDING" {
            report {"error": f"Submission is already {d.status}."};
            disengage;
        }
        d.status = "APPROVED";
        d.approved_at = now_iso();
        # already WritePerm-granted at submission; keep it that way so the
        # community feed can read it once its servings run out too
        grant(d, level=WritePerm);
        report {
            "approved": jid(d),
            "food_name": d.food_name,
            "org_name": org.contact_name
        };
    }
}

"""Reject a submission; it never becomes public."""
walker:priv RejectDonation {
    has donation_id: str,
        reason: str = "",
        reports: list[dict] = [];

    can reject with Root entry {
        mine = [root-->][?:Organization];
        if not mine {
            report {"error": "No organization registered for this account."};
            disengage;
        }
        org = mine[0];
        d = get_node(self.donation_id);
        if d is None or not isinstance(d, Donation) {
            report {"error": "Submission not found."};
            disengage;
        }
        if d.org_id != jid(org) {
            report {"error": "This submission was not sent to your organization."};
            disengage;
        }
        if d.status != "PENDING" {
            report {"error": f"Submission is already {d.status}."};
            disengage;
        }
        d.status = "REJECTED";
        d.rejected_at = now_iso();
        d.rejection_reason = self.reason;
        report {"rejected": jid(d), "food_name": d.food_name};
    }
}

"""Submissions this organization has already reviewed."""
walker:priv ListReviewedDonations {
    has reports: list[dict] = [];

    can read with Root entry {
        mine = [root-->][?:Organization];
        if not mine {
            report {"error": "No organization registered for this account."};
            disengage;
        }
        org = mine[0];
        org_id = jid(org);
        seen: dict = {};
        for r in allroots() {
            for d in [r-->][?:Donation] {
                if jid(d) in seen {
                    continue;
                }
                seen[jid(d)] = True;
                if d.status == "PENDING" {
                    continue;
                }
                if d.org_id != org_id {
                    continue;
                }
                report {
                    "id": jid(d),
                    "food_name": d.food_name,
                    "image_url": d.image_url,
                    "donated_servings": d.donated_servings,
                    "status": d.status,
                    "rejection_reason": d.rejection_reason,
                    "created_at": d.created_at
                };
            }
        }
    }
}

"""Dashboard counters for the logged-in organization."""
walker:priv OrgDashboard {
    has reports: list[dict] = [];

    can read with Root entry {
        mine = [root-->][?:Organization];
        if not mine {
            report {"error": "No organization registered for this account."};
            disengage;
        }
        org = mine[0];
        pending: int = 0;
        approved: int = 0;
        rejected: int = 0;
        reserved_servings: int = 0;
        available_servings_total: int = 0;
        org_id = jid(org);
        seen: dict = {};
        for r in allroots() {
            for d in [r-->][?:Donation] {
                if jid(d) in seen {
                    continue;
                }
                seen[jid(d)] = True;
                if d.org_id != org_id {
                    continue;
                }
                if d.status == "PENDING" {
                    pending += 1;
                } elif d.status == "APPROVED" {
                    approved += 1;
                    st = display_status(d);
                    if st != "EXPIRED" {
                        available_servings_total += available_servings(d);
                        reserved_servings += active_reserved(d);
                    }
                } elif d.status == "REJECTED" {
                    rejected += 1;
                }
            }
        }
        report {
            "pending": pending,
            "approved": approved,
            "rejected": rejected,
            "servings_available": available_servings_total,
            "servings_reserved": reserved_servings
        };
    }
}

# ------------------------------------------------------- community side --

"""TEMP DEBUG: inspect what allroots() surfaces for the caller."""
walker:priv DebugRoots {
    has reports: list[dict] = [];

    can inspect with Root entry {
        roots = allroots();
        report {"my_root": jid(root), "count": len(roots)};
        for r in roots {
            kids = [r-->];
            types = [k.__class__.__name__ for k in kids];
            report {"root": jid(r), "children": len(kids), "types": types[0:6]};
        }
    }
}

"""Public feed: APPROVED, unexpired donations with free servings left."""
walker:pub ListAvailableFood {
    has reports: list[dict] = [];

    can browse with Root entry {
        out: list[dict] = [];
        seen: dict = {};
        for r in allroots() {
            for d in [r-->][?:Donation] {
                if jid(d) in seen {
                    continue;
                }
                seen[jid(d)] = True;
                if d.status != "APPROVED" {
                    continue;
                }
                st = display_status(d);
                if st in ("EXPIRED", "FULLY_RESERVED") {
                    continue;
                }
                org_name = "";
                org_address = "";
                org_hours = "";
                org = get_node(d.org_id);
                if org is not None and isinstance(org, Organization) {
                    org_name = org.contact_name;
                    org_address = org.address;
                    org_hours = org.pickup_hours;
                }
                out.append({
                    "id": jid(d),
                    "food_name": d.food_name,
                    "image_url": d.image_url,
                    "ai_ingredients": d.ai_ingredients,
                    "ai_serving_size": d.ai_serving_size,
                    "ai_nutrition": d.ai_nutrition,
                    "servings_available": available_servings(d),
                    "donated_servings": d.donated_servings,
                    "display_status": st,
                    "org_name": org_name,
                    "org_address": org_address,
                    "pickup_hours": org_hours
                });
            }
        }
        for item in out {
            report item;
        }
    }
}

"""Claim servings: creates a Reservation held by the caller."""
walker:priv ClaimFood {
    has donation_id: str,
        servings: int = 1,
        reports: list[dict] = [];

    can claim with Root entry {
        if self.servings < 1 {
            report {"error": "Reserve at least 1 serving."};
            disengage;
        }
        d = get_node(self.donation_id);
        if d is None or not isinstance(d, Donation) {
            report {"error": "Food not found."};
            disengage;
        }
        if d.status != "APPROVED" or display_status(d) in ("EXPIRED", "FULLY_RESERVED") {
            report {"error": "This food is no longer available."};
            disengage;
        }
        left = available_servings(d);
        if self.servings > left {
            report {
                "error": (
                    f"Only {left} serving(s) left - you asked for {self.servings}. "
                    "A neighbor may have beaten you to it."
                )
            };
            disengage;
        }
        res = (root ++> Reservation(
            donation_id=jid(d),
            code=gen_reservation_code(),
            servings=self.servings,
            status="RESERVED",
            reserved_at=now_iso()
        ))[0];
        # reservations are readable platform-wide so availability math and
        # code uniqueness checks can see them; they carry no donor identity
        grant(res, level=ReadPerm);
        report {
            "code": res.code,
            "servings": self.servings,
            "food_name": d.food_name,
            "donation_id": jid(d),
            "reserved_at": res.reserved_at
        };
    }
}

"""The caller's own reservations with pickup details for each."""
walker:priv ListMyReservations {
    has reports: list[dict] = [];

    can read with Root entry {
        out: list[dict] = [];
        for res in [root-->][?:Reservation] {
            d = get_node(res.donation_id);
            food_name = "";
            image_url = "";
            org_name = "";
            org_address = "";
            org_hours = "";
            if d is not None and isinstance(d, Donation) {
                food_name = d.food_name;
                image_url = d.image_url;
                org = get_node(d.org_id);
                if org is not None and isinstance(org, Organization) {
                    org_name = org.contact_name;
                    org_address = org.address;
                    org_hours = org.pickup_hours;
                }
            }
            out.append({
                "code": res.code,
                "donation_id": res.donation_id,
                "food_name": food_name,
                "image_url": image_url,
                "servings": res.servings,
                "status": res.status,
                "reserved_at": res.reserved_at,
                "org_name": org_name,
                "org_address": org_address,
                "pickup_hours": org_hours
            });
        }
        for item in out {
            report item;
        }
    }
}

"""Cancel a RESERVED reservation and hand the servings back."""
walker:priv CancelReservation {
    has code: str,
        reports: list[dict] = [];

    can cancel with Root entry {
        for res in [root-->][?:Reservation] {
            if res.code == self.code and res.status == "RESERVED" {
                res.status = "CANCELLED";
                res.cancelled_at = now_iso();
                report {"cancelled": res.code};
                disengage;
            }
        }
        report {"error": "Reservation not found or already closed."};
    }
}

"""Mark one of the caller's reservations as picked up."""
walker:priv MarkPickedUp {
    has code: str,
        reports: list[dict] = [];

    can mark with Root entry {
        for res in [root-->][?:Reservation] {
            if res.code == self.code and res.status == "RESERVED" {
                res.status = "PICKED_UP";
                res.picked_up_at = now_iso();
                report {"picked_up": res.code};
                disengage;
            }
        }
        report {"error": "Reservation not found or already closed."};
    }
}
