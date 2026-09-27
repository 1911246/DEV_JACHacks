cl import from "react" { useState }
cl import from "@jac/runtime" { Link, jacIsLoggedIn, useNavigate }

sv import from ..endpoints {
    AnalyzeFoodPhoto,
    SubmitDonation,
    ListMyDonations,
    ListOrganizations
}

"""Donor portal page."""
cl {
    def:pub page -> JsxPage {
        navigate = useNavigate();
        (step, set_step) = useState(1);
        (image_url, set_image_url) = useState("");
        (analyzing, set_analyzing) = useState(False);
        (ai_error, set_ai_error) = useState("");
        (ingredients, set_ingredients) = useState("");
        (serving_size, set_serving_size) = useState("");
        (calories, set_calories) = useState("");
        (protein, set_protein) = useState("");
        (carbs, set_carbs) = useState("");
        (fat, set_fat) = useState("");
        (food_name, set_food_name) = useState("");
        (servings, set_servings) = useState(1);
        (prep_date, set_prep_date) = useState("");
        (expiry, set_expiry) = useState("");
        (notes, set_notes) = useState("");
        (orgs, set_orgs) = useState([] as list[dict]);
        (org_id, set_org_id) = useState("");
        (submit_error, set_submit_error) = useState("");
        (submitted, set_submitted) = useState(False);
        (history, set_history) = useState([] as list[dict]);

        async def load_side -> None {
            org_result = root spawn ListOrganizations();
            org_fresh: list[dict] = [];
            for x in org_result.reports {
                if x is not None {
                    org_fresh.append(x as dict);
                }
            }
            set_orgs(org_fresh);
            if jacIsLoggedIn() {
                hist_result = root spawn ListMyDonations();
                hist_fresh: list[dict] = [];
                for x in hist_result.reports {
                    if x is not None {
                        hist_fresh.append(x as dict);
                    }
                }
                set_history(hist_fresh);
            }
        }

        can with entry {
            load_side();
        }

        # Keep photos well under server request limits: 4 MB raw,
        # ~5.4 MB once base64-encoded into a data URL.
        MAX_PHOTO_BYTES: int = 4 * 1024 * 1024;

        def on_photo_chosen(e: any) -> None {
            set_ai_error("");
            files = e.target.files;
            # Browser FileList has no .map - count with .length instead
            # (a comprehension here compiles to files.map and crashes).
            n_files = files.length if files is not None else 0;
            if n_files == 0 {
                return;
            }
            file = files[0];
            if file.size > MAX_PHOTO_BYTES {
                set_ai_error("That photo is over 4 MB. Pick a smaller one (your phone's 'share' menu can resize it).");
                return;
            }
            set_analyzing(False);
            reader: any = new(FileReader);  # jac:ignore[E1053]
            def on_loaded(ev: any) -> None {
                data_url = str(reader.result);
                set_image_url(data_url);
            }
            reader.onload = on_loaded;
            reader.readAsDataURL(file);
        }

        async def submit_photo -> None {
            if not image_url {
                set_ai_error("Choose a photo first, chef.");
                return;
            }
            set_analyzing(True);
            set_ai_error("");
            analyze_photo(str(image_url));
        }

        async def analyze_photo(data_url: str) -> None {
            try {
                result = root spawn AnalyzeFoodPhoto(image_data=data_url);
                got: dict = {};
                for x in result.reports {
                    if x is not None {
                        got = x as dict;
                    }
                }
                if got.get("error") {
                    set_ai_error(str(got.get("error", "Could not read the photo.")));
                    set_analyzing(False);
                    return;
                }
                raw_ings = got.get("ingredients", []);
                names: list = [];
                if isinstance(raw_ings, list) {
                    for ing in raw_ings {
                        names.append(str(ing));
                    }
                }
                set_ingredients(", ".join(names));
                set_serving_size(str(got.get("serving_size", "")));
                nutrition = got.get("nutrition", {});
                set_calories(str(nutrition.get("calories", "")));
                set_protein(str(nutrition.get("protein", "")));
                set_carbs(str(nutrition.get("carbohydrates", "")));
                set_fat(str(nutrition.get("fat", "")));
                set_step(2);
            } except Exception as err {
                set_ai_error("AI analysis failed: " + str(err));
            }
            set_analyzing(False);
        }

        def go_to_details -> None {
            set_submit_error("");
            set_step(3);
        }

        async def submit_food -> None {
            set_submit_error("");
            if not str(food_name).strip() or not org_id {
                set_submit_error("A food name and an organization are needed.");
                return;
            }
            name_txt = str(food_name).strip();
            parts = str(ingredients).split(",");
            ing_list: list = [];
            for p in parts {
                if p.strip() {
                    ing_list.append(p.strip().lower());
                }
            }
            nutrition: dict = {
                "calories": str(calories),
                "protein": str(protein),
                "carbohydrates": str(carbs),
                "fat": str(fat)
            };
            result = root spawn SubmitDonation(
                org_id=str(org_id),
                image_data=str(image_url),
                food_name=name_txt,
                servings=int(servings),
                ai_ingredients=ing_list,
                ai_serving_size=str(serving_size),
                ai_nutrition=nutrition,
                preparation_date=str(prep_date),
                expiration_date=str(expiry),
                donor_notes=str(notes)
            );
            got: dict = {};
            for x in result.reports {
                if x is not None {
                    got = x as dict;
                }
            }
            if got.get("error") {
                set_submit_error(str(got.get("error", "Submission failed.")));
                return;
            }
            set_submitted(True);
            set_step(4);
            hist_result = root spawn ListMyDonations();
            hist_fresh: list[dict] = [];
            for x in hist_result.reports {
                if x is not None {
                    hist_fresh.append(x as dict);
                }
            }
            set_history(hist_fresh);
        }

        def start_new -> None {
            set_step(1);
            set_image_url("");
            set_ingredients("");
            set_serving_size("");
            set_calories("");
            set_protein("");
            set_carbs("");
            set_fat("");
            set_food_name("");
            set_servings(1);
            set_prep_date("");
            set_expiry("");
            set_notes("");
            set_org_id("");
            set_submitted(False);
        }

        def org_name_by_id(oid: any) -> str {
            for o in (orgs as list[dict]) {
                if str(o.get("id", "")) == str(oid) {
                    return str(o.get("name", "the organization"));
                }
            }
            return "the organization";
        }

        def dec_servings -> None {
            cur = int(servings);
            if cur > 1 {
                set_servings(cur - 1);
            }
        }

        def inc_servings -> None {
            cur = int(servings);
            if cur < 99 {
                set_servings(cur + 1);
            }
        }

        def render_history_row(d: dict) -> JsxElement {
            status = str(d.get("status", "PENDING"));
            return
                <div className="fb-row" key={str(d.get("id", ""))}>
                    <img className="thumb" src={str(d.get("image_url", ""))} alt={str(d.get("food_name", ""))}/>
                    <div className="grow">
                        <h3>{str(d.get("food_name", ""))}</h3>
                        <div className="fb-meta">
                            {str(d.get("donated_servings", "")) + " servings - submitted " + str(d.get("created_at", ""))}
                        </div>
                        {d.get("donor_notes") and <div className="fb-meta">{"\"" + str(d.get("donor_notes")) + "\""}</div>}
                    </div>
                    <span className={"badge " + status.lower()}>
                        {("Waiting for organization approval" if status == "PENDING" else status)}
                    </span>
                </div>;
        }

        def render_history -> list {
            rows: list = [];
            for d in (history as list[dict]) {
                rows.append(render_history_row(d));
            }
            return rows;
        }

        if not jacIsLoggedIn() {
            return
                <div className="fb-form" style={{"textAlign": "center"}}>
                    <h2>Donate Food</h2>
                    <p className="fb-note">You will need a donor account to share food.</p>
                    <div className="btn-row" style={{"justifyContent": "center", "marginTop": "0.8rem"}}>
                        <Link to="/login" className="btn primary">Log in</Link>
                        <Link to="/signup" className="btn leaf">Sign up as a donor</Link>
                    </div>
                </div>;
        }

        return
            <div>
                <div className="fb-section">
                    <h2>Donate Food</h2>
                    <span className="hint">Three little steps. Your extra becomes someone's dinner.</span>
                </div>

                <div className="fb-steps">
                    <span className={"fb-step" + (" on" if step == 1 else "")}>1. Photo</span>
                    <span className={"fb-step" + (" on" if step == 2 else "")}>2. AI check</span>
                    <span className={"fb-step" + (" on" if step == 3 else "")}>3. Details</span>
                </div>

                {submitted and (
                    <div className="fb-form" style={{"textAlign": "center"}}>
                        <div className="mascot-row small">
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/carrot.png" alt="carrot"/></span>
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/pepper.png" alt="pepper"/></span>
                        </div>
                        <h2 className="pop-in">Your food is off to find a good home!</h2>
                        <p className="fb-note">
                            {"Waiting for " + org_name_by_id(org_id) + " to review it. You will see its status below."}
                        </p>
                        <div className="btn-row" style={{"justifyContent": "center"}}>
                            <button className="btn leaf" onClick={start_new}>Donate something else</button>
                        </div>
                    </div>
                )}

                {step == 1 and not submitted and (
                    <div className="fb-form">
                        <h3>Step 1 - Show us the food</h3>
                        <p className="fb-note">Take a photo with your phone or pick one from your gallery.</p>
                        <input type="file" accept="image/*" capture="environment" onChange={on_photo_chosen} style={{"marginTop": "0.8rem"}}/>
                        <div className="fb-note" style={{"fontSize": "0.85rem"}}>{"Photos up to 4 MB."}</div>
                        {image_url and not analyzing and <img className="fb-card-img" style={{"maxWidth": "340px", "borderRadius": "14px", "marginTop": "0.8rem"}} src={image_url} alt="food preview"/>}
                        {image_url and not analyzing and (
                            <div className="btn-row" style={{"marginTop": "0.8rem"}}>
                                <button className="btn primary" onClick={submit_photo}>Submit photo - check with AI</button>
                            </div>
                        )}
                        {analyzing and <p className="fb-loading">Looking closely at your photo...</p>}
                        {ai_error and <div className="fb-error">{ai_error}</div>}
                    </div>
                )}

                {step == 2 and not submitted and (
                    <div className="fb-form wide">
                        <h3>Step 2 - Check the AI's reading</h3>
                        <p className="fb-note">AI-generated estimates - please review before submitting. Fix anything that looks off; you know your dish best.</p>
                        <img className="fb-card-img" style={{"maxWidth": "300px", "borderRadius": "14px"}} src={image_url} alt="your dish"/>
                        <div className="fb-field">
                            <label>Approximate ingredients (comma separated)</label>
                            <textarea value={ingredients} onChange={lambda e: ChangeEvent { set_ingredients(e.target.value); }} rows={2}/>
                        </div>
                        <div className="fb-field">
                            <label>Estimated serving size</label>
                            <input value={serving_size} onChange={lambda e: ChangeEvent { set_serving_size(e.target.value); }}/>
                        </div>
                        <div className="fb-row2">
                            <div className="fb-field">
                                <label>Calories per serving</label>
                                <input value={calories} onChange={lambda e: ChangeEvent { set_calories(e.target.value); }}/>
                            </div>
                            <div className="fb-field">
                                <label>Protein</label>
                                <input value={protein} onChange={lambda e: ChangeEvent { set_protein(e.target.value); }}/>
                            </div>
                            <div className="fb-field">
                                <label>Carbohydrates</label>
                                <input value={carbs} onChange={lambda e: ChangeEvent { set_carbs(e.target.value); }}/>
                            </div>
                            <div className="fb-field">
                                <label>Fat</label>
                                <input value={fat} onChange={lambda e: ChangeEvent { set_fat(e.target.value); }}/>
                            </div>
                        </div>
                        <div className="btn-row">
                            <button className="btn primary" onClick={go_to_details}>Looks right - continue</button>
                            <button className="btn" onClick={lambda { set_step(1); }}>Retake photo</button>
                        </div>
                    </div>
                )}

                {step == 3 and not submitted and (
                    <div className="fb-form wide">
                        <h3>Step 3 - The details only you know</h3>
                        <div className="fb-field">
                            <label>Food name</label>
                            <input value={food_name} onChange={lambda e: ChangeEvent { set_food_name(e.target.value); }} placeholder="e.g. Chicken & Vegetable Pasta"/>
                        </div>
                        <div className="fb-row2">
                            <div className="fb-field">
                                <label>Servings donated</label>
                                <div className="fb-qty">
                                    <button type="button" onClick={lambda { dec_servings(); }}>-</button>
                                    <span className="num">{str(servings)}</span>
                                    <button type="button" onClick={lambda { inc_servings(); }}>+</button>
                                </div>
                            </div>
                            <div className="fb-field">
                                <label>Preparation date</label>
                                <input type="date" value={prep_date} onChange={lambda e: ChangeEvent { set_prep_date(e.target.value); }}/>
                            </div>
                        </div>
                        <div className="fb-field">
                            <label>Best-by date (if you know it)</label>
                            <input type="date" value={expiry} onChange={lambda e: ChangeEvent { set_expiry(e.target.value); }}/>
                        </div>
                        <div className="fb-field">
                            <label>Notes for the organization</label>
                            <textarea value={notes} onChange={lambda e: ChangeEvent { set_notes(e.target.value); }} rows={2} placeholder="e.g. made too much for the block party, kept refrigerated"/>
                        </div>
                        <div className="fb-field">
                            <label>Drop it off with...</label>
                            {(
                                <div className="fb-note">No organizations have joined yet - invite a local one!</div>
                            ) if len(orgs as list[dict]) == 0 else (
                                <div className="fb-list">
                                    {[
                                        <div
                                            key={str(o.get("id", ""))}
                                            className={"role-card" + (" selected" if org_id == o.get("id") else "")}
                                            style={{"textAlign": "left", "padding": "0.7rem 0.9rem"}}
                                            onClick={lambda { set_org_id(str(o.get("id", ""))); }}
                                        >
                                            <b>{str(o.get("name", ""))}</b>
                                            <div>{str(o.get("address", ""))}</div>
                                            <div>{"Pickup hours: " + str(o.get("pickup_hours", ""))}</div>
                                            <div className="fb-note">{"Accepts: " + str(o.get("accepted_food_types", ""))}</div>
                                        </div> for o in (orgs as list[dict])
                                    ]}
                                </div>
                            )}
                        </div>
                        {submit_error and <div className="fb-error">{submit_error}</div>}
                        <div className="btn-row">
                            <button className="btn primary" onClick={submit_food}>Submit for review</button>
                            <button className="btn" onClick={lambda { set_step(2); }}>Back</button>
                        </div>
                    </div>
                )}

                <div className="fb-section">
                    <h2>My submissions</h2>
                    <span className="hint">Where each dish is on its journey.</span>
                </div>

                {len(history as list[dict]) == 0 and (
                    <div className="fb-empty">
                        <div className="mascot-row small">
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/broccoli.png" alt="broccoli"/></span>
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/eggplant.png" alt="eggplant"/></span>
                        </div>
                        No submissions yet. Your first donation is one photo away.
                    </div>
                )}
                <div className="fb-list">{render_history()}</div>
            </div>;
    }
}
