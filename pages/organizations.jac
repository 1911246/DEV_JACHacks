cl import from "react" { useState }
cl import from "@jac/runtime" { Link, jacIsLoggedIn }

sv import from ..endpoints { ListOrganizations, RegisterOrganization, GetProfile }

"""Organizations directory + registration."""
cl {
    def:pub page -> JsxPage {
        (orgs, set_orgs) = useState([] as list[dict]);
        (role, set_role) = useState("");
        (show_form, set_show_form) = useState(False);
        (org_name, set_org_name) = useState("");
        (org_type, set_org_type) = useState("Community Center");
        (contact_name, set_contact_name) = useState("");
        (phone, set_phone) = useState("");
        (address, set_address) = useState("");
        (pickup_hours, set_pickup_hours) = useState("");
        (accepted, set_accepted) = useState("");
        (refrig, set_refrig) = useState("Yes");
        (storage, set_storage) = useState("");
        (description, set_description) = useState("");
        (error, set_error) = useState("");
        (done, set_done) = useState("");
        (loaded, set_loaded) = useState(False);

        async def load -> None {
            # ListOrganizations is :pub, but GetProfile is :priv - calling it
            # logged out 401s and the runtime force-reloads the page forever.
            if not jacIsLoggedIn() {
                set_loaded(True);
                return;
            }
            result = root spawn ListOrganizations();
            fresh: list[dict] = [];
            for x in result.reports {
                if x is not None {
                    fresh.append(x as dict);
                }
            }
            set_orgs(fresh);
            prof = root spawn GetProfile();
            for p in prof.reports {
                if p is not None {
                    set_role(str(p.get("role", "")));
                }
            }
            set_loaded(True);
        }

        can with entry {
            load();
        }

        async def register_org(e: any) -> None {
            e.preventDefault();
            set_error("");
            result = root spawn RegisterOrganization(
                org_name=str(org_name),
                org_type=str(org_type),
                contact_name=str(contact_name),
                phone=str(phone),
                address=str(address),
                pickup_hours=str(pickup_hours),
                accepted_food_types=str(accepted),
                refrigeration=(str(refrig) == "Yes"),
                storage=str(storage),
                description=str(description)
            );
            got: dict = {};
            for x in result.reports {
                if x is not None {
                    got = x as dict;
                }
            }
            if got.get("error") {
                set_error(str(got.get("error", "Registration failed.")));
                return;
            }
            set_done(str(got.get("name", "Your organization")));
            set_show_form(False);
            load();
        }

        def render_org_card(o: dict) -> JsxElement {
            return
                <div className="fb-card" key={str(o.get("id", ""))}>
                    <div className="fb-card-body">
                        <div className="fb-card-title">{str(o.get("name", ""))}</div>
                        <span className="badge">{str(o.get("org_type", ""))}</span>
                        <div className="fb-pickup">
                            <b>Address</b><br/>
                            {str(o.get("address", ""))}<br/>
                            <b>Pickup hours</b><br/>
                            {str(o.get("pickup_hours", ""))}<br/>
                            <b>Accepts</b><br/>
                            {str(o.get("accepted_food_types", ""))}
                        </div>
                        {o.get("refrigeration") and <span className="badge approved">Refrigeration</span>}
                        <div className="fb-meta">{str(o.get("description", ""))}</div>
                    </div>
                </div>;
        }

        def render_orgs -> list {
            cards: list = [];
            for o in (orgs as list[dict]) {
                cards.append(render_org_card(o));
            }
            return cards;
        }

        n_orgs = len(orgs as list[dict]);
        can_register = role == "" or role == "ORGANIZATION";

        if loaded and not jacIsLoggedIn() {
            return
                <div className="fb-form" style={{"textAlign": "center"}}>
                    <h2>Neighbor Organizations</h2>
                    <p className="fb-note">
                        The directory of community hubs is for members.
                        Log in to browse organizations, or sign up to join the table!
                    </p>
                    <div className="btn-row" style={{"justifyContent": "center"}}>
                        <Link to="/login" className="btn primary">Log in</Link>
                        <Link to="/signup" className="btn">Sign up</Link>
                    </div>
                </div>;
        }

        return
            <div>
                <div className="fb-section">
                    <h2>Neighbor Organizations</h2>
                    <span className="hint">The community hubs that review and hand out food.</span>
                </div>

                {(
                    <div className="fb-empty">
                        <div className="mascot-row small">
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/orange.png" alt="orange"/></span>
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/carrot.png" alt="carrot"/></span>
                        </div>
                        No organizations have joined the board yet.
                        Know a food bank or community center? Invite them in!
                    </div>
                ) if n_orgs == 0 else (
                    <div className="fb-grid">{render_orgs()}</div>
                )}

                <div className="fb-section">
                    <h2>Join as an organization</h2>
                    <span className="hint">Open your doors as a drop-off and pickup spot.</span>
                </div>

                {done and (
                    <div className="fb-form" style={{"textAlign": "center"}}>
                        <h3 className="pop-in">{str(done) + " is on the board!"}</h3>
                        <p className="fb-note">Donors can now send food your way.</p>
                        <div className="btn-row" style={{"justifyContent": "center"}}>
                            <Link to="/organization_dashboard" className="btn leaf">Go to my dashboard</Link>
                        </div>
                    </div>
                )}

                {not done and not show_form and (
                    <div className="fb-form" style={{"textAlign": "center"}}>
                        {jacIsLoggedIn() and (
                            <div>
                                <p className="fb-note">
                                    {("This is a " + str(role) + " account - sign up as an Organization to register one.")
                                        if not can_register else
                                        "Register your organization to start receiving donations."}
                                </p>
                                <button
                                    className="btn primary"
                                    disabled={not can_register}
                                    onClick={lambda { set_show_form(True); }}
                                >
                                    Register my organization
                                </button>
                            </div>
                        ) or (
                            <div>
                                <p className="fb-note">Sign up as an Organization first, then register here.</p>
                                <div className="btn-row" style={{"justifyContent": "center"}}>
                                    <Link to="/signup" className="btn primary">Sign up</Link>
                                    <Link to="/login" className="btn">Log in</Link>
                                </div>
                            </div>
                        )}
                    </div>
                )}

                {show_form and not done and (
                    <form className="fb-form wide" onSubmit={register_org}>
                        <h3>Tell the neighborhood about your place</h3>
                        <div className="fb-row2">
                            <div className="fb-field">
                                <label>Organization name</label>
                                <input value={org_name} onChange={lambda e: ChangeEvent { set_org_name(e.target.value); }}/>
                            </div>
                            <div className="fb-field">
                                <label>Type</label>
                                <select value={org_type} onChange={lambda e: ChangeEvent { set_org_type(e.target.value); }}>
                                    <option>Community Center</option>
                                    <option>Food Pantry</option>
                                    <option>Church / Temple</option>
                                    <option>School</option>
                                    <option>Shelter</option>
                                    <option>Other</option>
                                </select>
                            </div>
                        </div>
                        <div className="fb-row2">
                            <div className="fb-field">
                                <label>Contact person</label>
                                <input value={contact_name} onChange={lambda e: ChangeEvent { set_contact_name(e.target.value); }}/>
                            </div>
                            <div className="fb-field">
                                <label>Phone</label>
                                <input value={phone} onChange={lambda e: ChangeEvent { set_phone(e.target.value); }}/>
                            </div>
                        </div>
                        <div className="fb-field">
                            <label>Address</label>
                            <input value={address} onChange={lambda e: ChangeEvent { set_address(e.target.value); }} placeholder="123 Main Street, Ann Arbor, MI"/>
                        </div>
                        <div className="fb-field">
                            <label>Pickup hours</label>
                            <input value={pickup_hours} onChange={lambda e: ChangeEvent { set_pickup_hours(e.target.value); }} placeholder="Mon-Fri: 4:00 PM - 7:00 PM"/>
                        </div>
                        <div className="fb-field">
                            <label>Types of food accepted</label>
                            <input value={accepted} onChange={lambda e: ChangeEvent { set_accepted(e.target.value); }} placeholder="prepared meals, produce, baked goods"/>
                        </div>
                        <div className="fb-row2">
                            <div className="fb-field">
                                <label>Refrigeration available</label>
                                <select value={refrig} onChange={lambda e: ChangeEvent { set_refrig(e.target.value); }}>
                                    <option>Yes</option>
                                    <option>No</option>
                                </select>
                            </div>
                            <div className="fb-field">
                                <label>Storage capabilities</label>
                                <input value={storage} onChange={lambda e: ChangeEvent { set_storage(e.target.value); }} placeholder="walk-in cooler, dry storage..."/>
                            </div>
                        </div>
                        <div className="fb-field">
                            <label>Description</label>
                            <textarea value={description} onChange={lambda e: ChangeEvent { set_description(e.target.value); }} rows={3}/>
                        </div>
                        {error and <div className="fb-error">{error}</div>}
                        <div className="btn-row">
                            <button type="submit" className="btn primary">Put us on the board</button>
                            <button type="button" className="btn" onClick={lambda { set_show_form(False); }}>Cancel</button>
                        </div>
                    </form>
                )}
            </div>;
    }
}
