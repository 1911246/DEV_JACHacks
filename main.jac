"""PlateMate - a community food redistribution platform.

Give Food. Find Food. Build Community.

The server-side workflow lives in endpoints.sv.jac (data model, walkers,
vision-AI analysis); this entry point merges it into the served module and
hosts the file-based client pages from pages/.
"""

import os;

"""Load .env from the project root into the process environment.

Keeps API keys (GROQ_API_KEY) out of the shell and out of git. Runs at
server startup, before the AI model config in lib.jac is used.
"""
def load_dotenv_file -> None {
    try {
        f = open(".env", "r");
        loaded: int = 0;
        for raw in f {
            line = str(raw).strip();
            if line and not line.startswith("#") and ("=" in line) {
                parts = line.split("=", 1);
                os.environ[parts[0].strip()] = parts[1].strip();
                loaded += 1;
            }
        }
        f.close();
        if loaded > 0 {
            print("[env] Loaded " + str(loaded) + " variable(s) from .env");
        }
    } except Exception { }
}

with entry {
    load_dotenv_file();
}

include endpoints;

# Importing the walker surface registers every endpoint with the API server
# (including the anonymous :pub walkers the community pages need).
import from endpoints {
    CompleteProfile,
    GetProfile,
    AnalyzeFoodPhoto,
    SubmitDonation,
    ListMyDonations,
    ListOrganizations,
    RegisterOrganization,
    GetMyOrganization,
    ListIncomingRequests,
    ApproveDonation,
    RejectDonation,
    ListReviewedDonations,
    OrgDashboard,
    ListAvailableFood,
    ClaimFood,
    ListMyReservations,
    CancelReservation,
    MarkPickedUp
}

# Warm, hand-drawn community styling shared by every page.
cl import "./styles.css";

cl {
    def:pub app(children: any = None) -> JsxElement {
        return <div>{children}</div>;
    }
}
