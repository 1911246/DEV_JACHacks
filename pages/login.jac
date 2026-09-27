cl import from "react" { useState }
cl import from "@jac/runtime" { Link, useNavigate, jacLogin }

sv import from ..endpoints { GetProfile, CompleteProfile }

"""Login page."""
cl {
    def:pub page -> JsxPage {
        (username, set_username) = useState("");
        (password, set_password) = useState("");
        (error, set_error) = useState("");
        navigate = useNavigate();

        async def submit(e: any) -> None {
            e.preventDefault();
            set_error("");
            uname = str(username).strip();
            if not uname or not password {
                set_error("Please fill in every field, neighbor.");
                return;
            }
            ok = await jacLogin(uname, str(password));
            if ok {
                prof = root spawn GetProfile();
                r = "";
                for p in prof.reports {
                    if p is not None {
                        r = str(p.get("role", ""));
                    }
                }
                if r == "" {
                    # Account predates the profile step (or was never finished)
                    # - heal it with a default Neighbor profile, then re-read.
                    root spawn CompleteProfile(role="RECIPIENT", display_name=uname);
                    prof = root spawn GetProfile();
                    for p in prof.reports {
                        if p is not None {
                            r = str(p.get("role", ""));
                        }
                    }
                }
                if r == "ORGANIZATION" {
                    navigate("/organization_dashboard");
                } else {
                    navigate("/");
                }
            } else {
                set_error("That name and password don't match our board. Try again?");
            }
        }

        return
            <div className="fb-form">
                <h2>Welcome back, neighbor</h2>
                <p className="fb-note">Sign in to claim food, donate, or review submissions.</p>
                <form onSubmit={submit}>
                    <div className="fb-field">
                        <label>Name or username</label>
                        <input value={username} onChange={lambda e: ChangeEvent { set_username(e.target.value); }} placeholder="e.g. nia_on_cedar"/>
                    </div>
                    <div className="fb-field">
                        <label>Password</label>
                        <input type="password" value={password} onChange={lambda e: ChangeEvent { set_password(e.target.value); }} placeholder="a little secret"/>
                    </div>
                    {error and <div className="fb-error">{error}</div>}
                    <div className="btn-row">
                        <button type="submit" className="btn primary">Log in</button>
                        <Link to="/signup" className="btn">New here? Sign up</Link>
                    </div>
                </form>
            </div>;
    }
}
