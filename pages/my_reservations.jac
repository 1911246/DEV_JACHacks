cl import from "react" { useState }
cl import from "@jac/runtime" { Link, jacIsLoggedIn }

sv import from ..endpoints { ListMyReservations, CancelReservation, MarkPickedUp }

"""Cozy status labels."""
cl {
    def status_label(status: str) -> str {
        if status == "RESERVED" {
            return "Heading your way";
        }
        if status == "PICKED_UP" {
            return "Picked up!";
        }
        if status == "CANCELLED" {
            return "Cancelled";
        }
        return "Expired";
    }

    def status_class(status: str) -> str {
        if status == "RESERVED" {
            return "reserved";
        }
        if status == "PICKED_UP" {
            return "picked";
        }
        if status == "CANCELLED" {
            return "cancelled";
        }
        return "";
    }
}

"""My Reservations page."""
cl {
    def:pub page -> JsxPage {
        (items, set_items) = useState([] as list[dict]);
        (loaded, set_loaded) = useState(False);
        (toast, set_toast) = useState("");

        async def load -> None {
            if not jacIsLoggedIn() {
                set_loaded(True);
                return;
            }
            result = root spawn ListMyReservations();
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

        async def cancel(code: str) -> None {
            root spawn CancelReservation(code=str(code));
            set_toast("Reservation " + str(code) + " cancelled - the servings are back on the table.");
            load();
        }

        async def picked_up(code: str) -> None {
            root spawn MarkPickedUp(code=str(code));
            set_toast("Enjoy! Marked " + str(code) + " as picked up.");
            load();
        }

        def render_row(r: dict) -> JsxElement {
            status = str(r.get("status", ""));
            return
                <div className="fb-row pop-in" key={str(r.get("code", ""))}>
                    <img className="thumb" src={str(r.get("image_url", ""))} alt={str(r.get("food_name", ""))}/>
                    <div className="grow">
                        <h3>{str(r.get("food_name", ""))}</h3>
                        <div className="fb-meta">
                            {str(r.get("servings", "")) + " servings - " + str(r.get("org_name", ""))}
                        </div>
                        <div className="fb-meta">{str(r.get("org_address", ""))}</div>
                        <div className="fb-meta">{"Pickup hours: " + str(r.get("pickup_hours", ""))}</div>
                        <div className="fb-meta">{"Reserved " + str(r.get("reserved_at", ""))}</div>
                        <div style={{"color": "var(--tomato)", "fontWeight": "bold", "letterSpacing": "0.1em"}}>
                            {str(r.get("code", ""))}
                        </div>
                    </div>
                    <div style={{"textAlign": "right"}}>
                        <span className={"badge " + status_class(status)}>
                            {status_label(status)}
                        </span>
                        {status == "RESERVED" and (
                            <div className="btn-row" style={{"marginTop": "0.6rem"}}>
                                <button className="btn small leaf" onClick={lambda { picked_up(str(r.get("code", ""))); }}>Picked up!</button>
                                <button className="btn small" onClick={lambda { cancel(str(r.get("code", ""))); }}>Cancel</button>
                            </div>
                        )}
                    </div>
                </div>;
        }

        def render_rows -> list {
            rows: list = [];
            for r in (items as list[dict]) {
                rows.append(render_row(r));
            }
            return rows;
        }

        n_items = 0;
        if loaded {
            n_items = len(items as list[dict]);
        }

        if loaded and not jacIsLoggedIn() {
            return
                <div className="fb-form" style={{"textAlign": "center"}}>
                    <h2>My Reservations</h2>
                    <p className="fb-note">Log in to see the food waiting for you.</p>
                    <div className="btn-row" style={{"justifyContent": "center", "marginTop": "0.6rem"}}>
                        <Link to="/login" className="btn primary">Log in</Link>
                        <Link to="/signup" className="btn leaf">Sign up</Link>
                    </div>
                </div>;
        }

        return
            <div>
                <div className="fb-section">
                    <h2>My Reservations</h2>
                    <span className="hint">Food with your name on it, neighbor.</span>
                </div>

                {loaded and n_items == 0 and (
                    <div className="fb-empty">
                        <div className="mascot-row small">
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/orange.png" alt="orange"/></span>
                            <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/banana.png" alt="banana"/></span>
                        </div>
                        Nothing reserved yet. Browse <Link to="/available">Available Food</Link> and
                        claim something tasty.
                    </div>
                )}

                {not loaded and <div className="fb-loading">Checking the pickup shelf...</div>}

                <div className="fb-list">{render_rows()}</div>

                {toast and <div className="fb-toast">{toast}</div>}
            </div>;
    }
}
