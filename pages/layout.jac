cl import from "@jac/runtime" { Link, Outlet, useLocation, jacIsLoggedIn, jacLogout, useNavigate }
cl {
    def:pub layout -> JsxElement {
        location = useLocation();
        navigate = useNavigate();

        def path_of(loc: any) -> str {
            return str(loc.pathname if hasattr(loc, "pathname") else "/");
        }

        def handleLogout(e: any) -> None {
            e.preventDefault();
            jacLogout();
            # Full reset: a hard reload drops every page's in-memory state so
            # the app lands on a truly fresh home, exactly like first visit.
            window.location.href = "/";
        }

        loggedIn = jacIsLoggedIn();

        can with entry {
            document.title = "PlateMate";
            # Favicon: the PlateMate logo (same image as the nav bar).
            if not document.querySelector("link[rel='icon']") {
                head_el: any = document.head;
                link_el: any = document.createElement("link");
                link_el.setAttribute("rel", "icon");
                link_el.setAttribute("type", "image/png");
                link_el.setAttribute("href", "/compiled/assets/PlateMate-logo.png");
                head_el.appendChild(link_el);
            }
        }

        # Organizations tab is member-only: it needs a logged-in account to
        # make sense (browse as a donor, or manage as an organization).
        links: list = [
            ("/", "Home"),
            ("/available", "Available Food"),
            ("/donate", "Donate Food")
        ];
        if loggedIn {
            links.append(("/organizations", "Organizations"));
        }

        return
            <div className="fb-shell">
                <nav className="fb-nav">
                    <Link to="/" className="fb-logo">
                        <img className="fb-logo-img" src="/compiled/assets/PlateMate-logo.png" alt="PlateMate"/>
                    </Link>
                    {[
                        <Link
                            key={l[0]}
                            to={l[0]}
                            className={"fb-navlink" + (" active" if path_of(location) == l[0] else "")}
                        >
                            {l[1]}
                        </Link> for l in links
                    ]}
                    {loggedIn and (
                        <span className="btn-row">
                            <Link to="/my_reservations" className="fb-navlink">My Reservations</Link>
                            <Link to="/organization_dashboard" className="fb-navlink">Org Dashboard</Link>
                            <button className="fb-navbtn" onClick={handleLogout}>Log out</button>
                        </span>
                    ) or (
                        <span className="btn-row">
                            <Link to="/login" className="fb-navlink">Login</Link>
                            <Link to="/signup" className="fb-navbtn solid">Sign Up</Link>
                        </span>
                    )}
                </nav>
                <main className="fb-main">
                    <Outlet/>
                </main>
                <footer className="fb-footer">
                    <div className="mascot-row small">
                        <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/carrot.png" alt="carrot"/></span>
                        <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/apple.png" alt="apple"/></span>
                        <span className="mascot-plate"><img className="mascot" src="/compiled/assets/mascots/banana.png" alt="banana"/></span>
                    </div>
                    <div>PlateMate - neighbors feeding neighbors, one plate at a time.</div>
                    <div className="fb-note">Built with Jac for JacHacks. Leave a little, take a little.</div>
                </footer>
            </div>;
    }
}
