cl import from "react" { useState }
cl import from "@jac/runtime" { Link, useNavigate, jacLogin, jacSignup, jacLogout, jacIsLoggedIn }

sv import from ..endpoints { CompleteProfile }

"""Signup page with the role picker."""
cl {
    def:pub page -> JsxPage {
        (username, set_username) = useState("");
        (password, set_password) = useState("");
        (role, set_role) = useState("RECIPIENT");
        (error, set_error) = useState("");
        (busy, set_busy) = useState(False);
        navigate = useNavigate();

        roles: list = [
            ("RECIPIENT", "Neighbor", "Find and reserve food"),
            ("DONOR", "Donor", "Share extra home food"),
            ("ORGANIZATION", "Organization", "Review and hand out food")
        ];

        async def submit(e: any) -> None {
            e.preventDefault();
            if busy {
                return;
            }
            set_error("");
            uname = str(username).strip();
            if not uname or not password {
                set_error("Please fill in every field, neighbor.");
                return;
            }
            set_busy(True);
            # A stale token from a previous session makes the next pages
            # 401-and-reload (the "glitch"). Start every signup clean.
            if jacIsLoggedIn() {
                jacLogout();
            }
            try {
                result = await jacSignup(uname, str(password));
                if result.get("success") {
                    logged = await jacLogin(uname, str(password));
                    if logged {
                        root spawn CompleteProfile(role=str(role), display_name=uname);
                        if role == "ORGANIZATION" {
                            navigate("/organization_dashboard");
                        } else {
                            navigate("/");
                        }
                    } else {
                        set_error("Account made, but sign-in hiccuped. Try logging in.");
                    }
                } else {
                    set_error(str(result.get("error", "Signup failed - that name may be taken.")));
                }
            } except Exception as err {
                set_error("Signup hiccuped: " + str(err));
            }
            set_busy(False);
        }

        return
            <div className="fb-form">
                <h2>Pull up a chair, neighbor</h2>
                <p className="fb-note">One account for the whole neighborhood table.</p>
                <form onSubmit={submit}>
                    <div className="fb-field">
                        <label>Name or username</label>
                        <input value={username} onChange={lambda e: ChangeEvent { set_username(e.target.value); }} placeholder="e.g. nia_on_cedar"/>
                    </div>
                    <div className="fb-field">
                        <label>Password</label>
                        <input type="password" value={password} onChange={lambda e: ChangeEvent { set_password(e.target.value); }} placeholder="a little secret"/>
                    </div>
                    <div className="fb-field">
                        <label>I am joining as...</label>
                        <div className="role-cards">
                            {[
                                <div
                                    key={str(r[0])}
                                    className={"role-card" + (" selected" if role == r[0] else "")}
                                    onClick={lambda { set_role(r[0]); }}
                                >
                                    <b>{r[1]}</b>
                                    {r[2]}
                                </div> for r in roles
                            ]}
                        </div>
                    </div>
                    {error and <div className="fb-error">{error}</div>}
                    <div className="btn-row">
                        <button type="submit" className="btn primary" disabled={busy}>{"Setting the table..." if busy else "Create my account"}</button>
                        <Link to="/login" className="btn">Have an account? Log in</Link>
                    </div>
                </form>
                <p className="fb-note" style={{"marginTop": "0.8rem"}}>
                    Donating food? Pick <b>Donor</b>. Picking up for your family?
                    <b>Neighbor</b>. Serving the community? <b>Organization</b>.
                </p>
            </div>;
    }
}
