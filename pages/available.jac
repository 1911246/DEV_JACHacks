cl import from "react" { useState }
cl import from "@jac/runtime" { Link, jacIsLoggedIn, useNavigate }

sv import from ..endpoints { ListAvailableFood, ClaimFood }

"""A single listing on the Available Food page."""
cl {
    def:pub AvailableCard(item: dict, onClaim: any) -> JsxElement {
        servings = int(item.get("servings_available", 0));
        ing_list: list = [];
        raw_ings = item.get("ingredients", []);
        if isinstance(raw_ings, list) {
            for ing in raw_ings {
                ing_list.append(str(ing));
            }
        }
        nutrition = item.get("ai_nutrition", {});
        return
            <div className="fb-card">
                <img className="fb-card-img" src={str(item.get("image_url", ""))} alt={str(item.get("food_name", ""))}/>
                <div className="fb-card-body">
                    <div className="fb-card-title">{str(item.get("food_name", ""))}</div>
                    <div className="fb-servings">
                        {str(servings) + (" serving" if servings == 1 else " servings") + " available"}
                    </div>
                    <details className="fb-ai">
                        <summary>AI Food Information</summary>
                        <div className="fb-ai-body">
                            <h4>Ingredients (AI estimate)</h4>
                            <ul>
                                {[<li key={str(ing)}>{ing}</li> for ing in ing_list]}
                            </ul>
                            <h4>Serving size (AI estimate)</h4>
                            <div>{str(item.get("ai_serving_size", ""))}</div>
                            <h4>Nutrition per serving (AI estimate)</h4>
                            <ul>
                                <li key="cal">{"Calories: " + str(nutrition.get("calories", "n/a"))}</li>
                                <li key="pro">{"Protein: " + str(nutrition.get("protein", "n/a"))}</li>
                                <li key="carb">{"Carbohydrates: " + str(nutrition.get("carbohydrates", "n/a"))}</li>
                                <li key="fat">{"Fat: " + str(nutrition.get("fat", "n/a"))}</li>
                            </ul>
                            <div className="fb-ai-note">
                                AI-generated estimates may not be exact. Verify ingredients
                                and nutrition when necessary.
                            </div>
                        </div>
                    </details>
                    <div className="fb-pickup">
                        <b>Pickup</b><br/>
                        {str(item.get("org_name", ""))}<br/>
                        {str(item.get("org_address", ""))}<br/>
                        {"Pickup hours: " + str(item.get("pickup_hours", ""))}
                    </div>
                    {(
                        <button className="btn primary" onClick={lambda { onClaim(item); }}>Claim Food</button>
                    ) if servings > 0 else (
                        <button className="btn" disabled={True}>Fully reserved</button>
                    )}
                </div>
            </div>;
    }
}

"""Available Food page."""
cl {
    def:pub page -> JsxPage {
        (items, set_items) = useState([] as list[dict]);
        (loaded, set_loaded) = useState(False);
        (claiming, set_claiming) = useState(None);
        (claim_id, set_claim_id) = useState("");
        (qty, set_qty) = useState(1);
        (confirmation, set_confirmation) = useState(None);
        (error, set_error) = useState("");
        navigate = useNavigate();

        async def load -> None {
            result = root spawn ListAvailableFood();
            fresh: list[dict] = [];
            for x in result.reports {
                if x is not None {
                    fresh.append(x as dict);
                }
            }
            set_items(fresh);
            set_loaded(True);
        }

        can with entry {
            load();
        }

        def open_claim(item: dict) -> None {
            if not jacIsLoggedIn() {
                navigate("/login");
                return;
            }
            set_error("");
            set_qty(1);
            set_claim_id(str(item.get("id", "")));
            set_claiming(item);
        }

        async def do_claim -> None {
            set_error("");
            result = root spawn ClaimFood(
                donation_id=str(claim_id),
                servings=int(qty)
            );
            got: dict = {};
            for x in result.reports {
                if x is not None {
                    got = x as dict;
                }
            }
            if got.get("error") {
                set_error(str(got.get("error", "Could not reserve.")));
                return;
            }
            set_confirmation(got);
            set_claiming(None);
            load();
        }

        def read_code(conf: any, key: str) -> str {
            if conf is None {
                return "";
            }
            return str(conf.get(key, ""));
        }

        def dec_qty -> None {
            cur = int(qty);
            if cur > 1 {
                set_qty(cur - 1);
            }
        }

        def inc_qty -> None {
            cur = int(qty);
            max_q = 1;
            if claiming is not None {
                max_q = int(read_code(claiming, "servings_available") or "1");
            }
            if cur < max_q {
                set_qty(cur + 1);
            }
        }

        def render_card(item: dict) -> JsxElement {
            return <AvailableCard key={str(item.get("id", ""))} item={item} onClaim={open_claim}/>;
        }

        def render_cards -> list {
            cards: list = [];
            for item in (items as list[dict]) {
                cards.append(render_card(item));
            }
            return cards;
        }

        n_items = 0;
        if loaded {
            n_items = len(items as list[dict]);
        }

        return
            <div>
                <div className="fb-section">
                    <h2>Available Food</h2>
                    <span className="hint">Every dish here was reviewed and approved by a local organization.</span>
                </div>
                {(
                    <div className="fb-empty">
                        <div className="mascot-row small">
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/banana.png" alt="banana"/></span>
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/apple.png" alt="apple"/></span>
                        </div>
                        The table is empty for now. Check back soon - neighbors
                        share food here every day.
                    </div>
                ) if n_items == 0 else (
                    <div className="fb-grid">{render_cards()}</div>
                )}

                {claiming and (
                    <div className="fb-modal-back">
                        <div className="fb-modal pop-in">
                            <h3>How many servings would you like?</h3>
                            <p>{read_code(claiming, "food_name")}</p>
                            <div className="fb-qty">
                                <button onClick={lambda { dec_qty(); }}>-</button>
                                <span className="num">{str(qty)}</span>
                                <button onClick={lambda { inc_qty(); }}>+</button>
                                <span className="fb-note">{"of " + read_code(claiming, "servings_available") + " available"}</span>
                            </div>
                            {error and <div className="fb-error">{error}</div>}
                            <div className="btn-row">
                                <button className="btn primary" onClick={do_claim}>Confirm Reservation</button>
                                <button className="btn" onClick={lambda { set_claiming(None); set_error(""); }}>Never mind</button>
                            </div>
                        </div>
                    </div>
                )}

                {confirmation and (
                    <div className="fb-modal-back">
                        <div className="fb-modal pop-in">
                            <div className="fb-confirm">
                                <div className="big">Food Reserved!</div>
                                <div className="mascot-row small">
                                    <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/carrot.png" alt="carrot"/></span>
                                </div>
                                <p>{"Food: " + read_code(confirmation, "food_name")}</p>
                                <p>{"Quantity: " + read_code(confirmation, "servings") + " servings"}</p>
                                <p className="code">{read_code(confirmation, "code")}</p>
                                <p className="fb-note">Nice! Head over whenever works for you and share this code.</p>
                                <div className="btn-row" style={{"justifyContent": "center"}}>
                                    <Link to="/my_reservations" className="btn leaf">See my reservations</Link>
                                    <button className="btn" onClick={lambda { set_confirmation(None); }}>Keep browsing</button>
                                </div>
                            </div>
                        </div>
                    </div>
                )}
            </div>;
    }
}
