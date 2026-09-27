cl import from "@jac/runtime" { Link, useNavigate, jacIsLoggedIn, jacLogout }

"""Top navigation shared by every page."""
cl {
    def:pub NavBar(path: str = "/") -> JsxElement {
        navigate = useNavigate();
        loggedIn = jacIsLoggedIn();

        def handleLogout(e: any) -> None {
            e.preventDefault();
            jacLogout();
            navigate("/");
        }

        # Organizations tab is member-only (see layout.jac note).
        links: list = [
            ("/", "Home"),
            ("/available", "Available Food"),
            ("/donate", "Donate Food")
        ];
        if loggedIn {
            links.append(("/organizations", "Organizations"));
        }

        return
            <nav class="fb-nav">
                <Link to="/" class="fb-logo">
                    <img class="fb-logo-img" src="/compiled/assets/PlateMate-logo.png" alt="PlateMate"/>
                </Link>
                {[
                    <Link
                        key={l[0]}
                        to={l[0]}
                        class={"fb-navlink" + (" active" if path == l[0] else "")}
                    >
                        {l[1]}
                    </Link> for l in links
                ]}
                {((
                    <span className="btn-row">
                        <Link to="/my_reservations" className="fb-navlink">My Reservations</Link>
                        <Link to="/organization_dashboard" className="fb-navlink">Org Dashboard</Link>
                        <button className="fb-navbtn" onClick={handleLogout}>Log out</button>
                    </span>
                ) if loggedIn else (
                    <span className="btn-row">
                        <Link to="/login" className="fb-navlink">Login</Link>
                        <Link to="/signup" className="fb-navbtn solid">Sign Up</Link>
                    </span>
                ))}
            </nav>;
    }
}
