cl import from "react" { useState }
cl import from "@jac/runtime" { Link, jacIsLoggedIn }

sv import from ..endpoints {
    GetProfile,
    GetMyOrganization,
    OrgDashboard,
    ListIncomingRequests,
    ApproveDonation,
    RejectDonation,
    ListReviewedDonations
}

"""Organization dashboard page."""
cl {
    def:pub page -> JsxPage {
        (role, set_role) = useState("");
        (org_name, set_org_name) = useState("");
        (org_registered, set_org_registered) = useState(False);
        (summary, set_summary) = useState(None);
        (requests, set_requests) = useState([] as list[dict]);
        (reviewed, set_reviewed) = useState([] as list[dict]);
        (rejecting, set_rejecting) = useState(None);
        (reject_id, set_reject_id) = useState("");
        (reject_reason, set_reject_reason) = useState("");
        (toast, set_toast) = useState("");
        (error, set_error) = useState("");

        def dicts_of(result: any) -> list {
            fresh: list[dict] = [];
            for x in result.reports {
                if x is not None {
                    fresh.append(x as dict);
                }
            }
            return fresh;
        }

        async def load_all -> None {
            if not jacIsLoggedIn() {
                set_role("ANON");
                return;
            }
            prof = root spawn GetProfile();
            r = "";
            for p in prof.reports {
                if p is not None {
                    r = str(p.get("role", ""));
                }
            }
            set_role(r);
            if r != "ORGANIZATION" {
                return;
            }
            mine = root spawn GetMyOrganization();
            for o in mine.reports {
                if o is not None {
                    set_org_name(str(o.get("contact_name", "")));
                    set_org_registered(True);
                }
            }
            s = root spawn OrgDashboard();
            for x in s.reports {
                if x is not None {
                    set_summary(x);
                }
            }
            reqs = root spawn ListIncomingRequests();
            set_requests(dicts_of(reqs));
            rev = root spawn ListReviewedDonations();
            set_reviewed(dicts_of(rev));
        }

        can with entry {
            load_all();
        }

        async def approve(donation_id: str) -> None {
            set_error("");
            result = root spawn ApproveDonation(donation_id=str(donation_id));
            for x in result.reports {
                if x is not None and x.get("error") {
                    set_error(str(x.get("error")));
                    return;
                }
            }
            set_toast("Handshake made! The food is now on the community board.");
            load_all();
        }

        async def reject_confirm -> None {
            set_error("");
            result = root spawn RejectDonation(donation_id=str(reject_id), reason=str(reject_reason));
            for x in result.reports {
                if x is not None and x.get("error") {
                    set_error(str(x.get("error")));
                    return;
                }
            }
            set_rejecting(None);
            set_reject_reason("");
            set_toast("Kindly declined. The donor has been notified.");
            load_all();
        }

        def read_num(summary: any, key: str) -> str {
            if summary is None {
                return "0";
            }
            return str(summary.get(key, 0));
        }

        def read_field(obj_dict: any, key: str) -> str {
            if obj_dict is None {
                return "";
            }
            return str(obj_dict.get(key, ""));
        }

        def render_request(d: dict) -> JsxElement {
            ings: list = [];
            raw = d.get("ai_ingredients", []);
            if isinstance(raw, list) {
                for ing in raw {
                    ings.append(str(ing));
                }
            }
            nutrition = d.get("ai_nutrition", {});
            return
                <div className="fb-row" key={str(d.get("id", ""))}>
                    <img className="thumb" src={str(d.get("image_url", ""))} alt={str(d.get("food_name", ""))}/>
                    <div className="grow">
                        <h3>{str(d.get("food_name", ""))}</h3>
                        <div className="fb-meta">
                            {str(d.get("donated_servings", "")) + " servings donated"}
                            {(" - prepared " + str(d.get("preparation_date"))) if d.get("preparation_date") else ""}
                            {(" - best by " + str(d.get("expiration_date"))) if d.get("expiration_date") else ""}
                        </div>
                        <div className="fb-meta">{"Submitted " + str(d.get("created_at", ""))}</div>
                        {d.get("donor_notes") and <div className="fb-meta">{"Donor says: \"" + str(d.get("donor_notes")) + "\""}</div>}
                        <details className="fb-ai" style={{"marginTop": "0.5rem"}}>
                            <summary>AI Food Information</summary>
                            <div className="fb-ai-body">
                                <h4>Ingredients (AI estimate)</h4>
                                <ul>{[<li key={str(ing)}>{ing}</li> for ing in ings]}</ul>
                                <h4>Serving size (AI estimate)</h4>
                                <div>{str(d.get("ai_serving_size", ""))}</div>
                                <h4>Nutrition per serving (AI estimate)</h4>
                                <ul>
                                    <li key="cal">{"Calories: " + str(nutrition.get("calories", "n/a"))}</li>
                                    <li key="pro">{"Protein: " + str(nutrition.get("protein", "n/a"))}</li>
                                    <li key="carb">{"Carbohydrates: " + str(nutrition.get("carbohydrates", "n/a"))}</li>
                                    <li key="fat">{"Fat: " + str(nutrition.get("fat", "n/a"))}</li>
                                </ul>
                            </div>
                        </details>
                    </div>
                    <div className="btn-row">
                        <button className="btn leaf" onClick={lambda { approve(str(d.get("id", ""))); }}>Approve</button>
                        <button className="btn" onClick={lambda { set_reject_id(str(d.get("id", ""))); set_rejecting(d); set_reject_reason(""); }}>Reject</button>
                    </div>
                </div>;
        }

        def render_requests -> list {
            rows: list = [];
            for d in (requests as list[dict]) {
                rows.append(render_request(d));
            }
            return rows;
        }

        def render_reviewed_row(d: dict) -> JsxElement {
            status = str(d.get("status", ""));
            return
                <div className="fb-row" key={str(d.get("id", ""))}>
                    <img className="thumb" src={str(d.get("image_url", ""))} alt={str(d.get("food_name", ""))}/>
                    <div className="grow">
                        <h3>{str(d.get("food_name", ""))}</h3>
                        <div className="fb-meta">{str(d.get("donated_servings", "")) + " servings - " + str(d.get("created_at", ""))}</div>
                        {d.get("rejection_reason") and <div className="fb-meta">{"Reason: " + str(d.get("rejection_reason"))}</div>}
                    </div>
                    <span className={"badge " + status.lower()}>{status}</span>
                </div>;
        }

        def render_reviewed -> list {
            rows: list = [];
            for d in (reviewed as list[dict]) {
                rows.append(render_reviewed_row(d));
            }
            return rows;
        }

        n_requests = len(requests as list[dict]);
        n_reviewed = len(reviewed as list[dict]);

        if role == "" or role == "ANON" {
            return
                <div className="fb-form" style={{"textAlign": "center"}}>
                    <h2>Organization Dashboard</h2>
                    <p className="fb-note">Please log in with your organization account.</p>
                    <div className="btn-row" style={{"justifyContent": "center"}}>
                        <Link to="/login" className="btn primary">Log in</Link>
                        <Link to="/signup" className="btn">Sign up as an organization</Link>
                    </div>
                </div>;
        }

        if role != "ORGANIZATION" {
            return
                <div className="fb-form" style={{"textAlign": "center"}}>
                    <h2>Organization Dashboard</h2>
                    <p className="fb-note">This room is for organization accounts.</p>
                    <div className="btn-row" style={{"justifyContent": "center"}}>
                        <Link to="/signup" className="btn primary">Sign up as an organization</Link>
                        <Link to="/login" className="btn">Log in</Link>
                    </div>
                </div>;
        }

        return
            <div>
                <div className="fb-section">
                    <h2>{str(org_name) + " - Dashboard"}</h2>
                    <span className="hint">A warm handshake between donors and neighbors.</span>
                </div>

                {not org_registered and (
                    <div className="fb-empty">
                        <div className="mascot-row small">
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/broccoli.png" alt="broccoli"/></span>
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/apple.png" alt="apple"/></span>
                        </div>
                        One more step: register your organization so donors can find you.
                        <div className="btn-row" style={{"justifyContent": "center", "marginTop": "0.8rem"}}>
                            <Link to="/organizations" className="btn primary">Register my organization</Link>
                        </div>
                    </div>
                )}

                <div className="fb-summary">
                    <div className="fb-stat"><div className="n">{read_num(summary, "pending")}</div><div className="l">Pending donor requests</div></div>
                    <div className="fb-stat"><div className="n">{read_num(summary, "approved")}</div><div className="l">Approved donations</div></div>
                    <div className="fb-stat"><div className="n">{read_num(summary, "servings_available")}</div><div className="l">Servings on the table</div></div>
                    <div className="fb-stat"><div className="n">{read_num(summary, "servings_reserved")}</div><div className="l">Servings reserved</div></div>
                    <div className="fb-stat"><div className="n">{read_num(summary, "rejected")}</div><div className="l">Declined</div></div>
                </div>

                <div className="fb-section">
                    <h2>Donor requests</h2>
                    <span className="hint">Review the photo and AI notes, then decide.</span>
                </div>

                {error and <div className="fb-error">{error}</div>}

                {n_requests == 0 and (
                    <div className="fb-empty">
                        <div className="mascot-row small">
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/eggplant.png" alt="eggplant"/></span>
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/pepper.png" alt="pepper"/></span>
                        </div>
                        No requests yet... the kitchen's quiet for now.
                    </div>
                )}

                <div className="fb-list">{render_requests()}</div>

                {n_reviewed > 0 and (
                    <div>
                        <div className="fb-section">
                            <h2>Already reviewed</h2>
                            <span className="hint">Your kitchen log.</span>
                        </div>
                        <div className="fb-list">{render_reviewed()}</div>
                    </div>
                )}

                {rejecting and (
                    <div className="fb-modal-back">
                        <div className="fb-modal pop-in">
                            <h3>{"Decline \"" + read_field(rejecting, "food_name") + "\"?"}</h3>
                            <p className="fb-note">A short, kind reason helps the donor out (optional).</p>
                            <div className="fb-field">
                                <input
                                    value={reject_reason}
                                    onChange={lambda e: ChangeEvent { set_reject_reason(e.target.value); }}
                                    placeholder="e.g. at capacity this week, try again Friday"
                                />
                            </div>
                            <div className="btn-row">
                                <button className="btn primary" onClick={reject_confirm}>Confirm decline</button>
                                <button className="btn" onClick={lambda { set_rejecting(None); }}>Never mind</button>
                            </div>
                        </div>
                    </div>
                )}

                {toast and <div className="fb-toast">{toast}</div>}
            </div>;
    }
}
