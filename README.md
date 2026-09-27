# Find-My-Food (PlateMate)

## Inspiration
Every day, massive amounts of perfectly good, nutritious food go to waste. On college campuses, students frequently find themselves with leftover catering from events, extra grocery staples before breaks, or surplus home-cooked meals they made too much of. At the same time, families and individuals in neighboring communities face deep food insecurity. 

We wanted to bridge this gap, but we recognized a glaring bottleneck: security, verification, and logistics. Donors don't always know where to drop food off safely, and recipients need to ensure the food they are getting is safe, properly stored, and dietary-transparent. We built **Find-My-Food** (production name: **PlateMate**) to serve as a warm, hand-drawn community bulletin board that eliminates this friction by routing campus and neighborhood donations through verified local non-profits and community intermediaries.

## What it does
Find-My-Food is a full-stack community food redistribution network that coordinates three distinct user roles into a seamless, trusted marketplace:

*   **Donors (College Students/Neighbors):** Can take a quick phone photo of extra prepared dishes or groceries. A built-in Vision AI instantly analyzes the image to estimate ingredients, serving size, and macro-nutrition, reducing the friction of manual data entry while providing a helpful safety check. Donors select an intermediary organization and submit the dish.
*   **Intermediaries (Verified Non-Profits, Pantries, Shelters):** Manage a custom organization dashboard. They evaluate incoming donor requests using the AI analysis and physical photos. Once approved, the food instantly goes live on the public community board, backed by the organization's refrigeration capabilities, specific pickup hours, and physical location mapping.
*   **Neighbors (Recipients):** Browse the public community feed of approved, unexpired dishes. They can inspect AI-generated ingredient lists (crucial for allergies) and dynamically claim exact serving portions. Upon making a reservation, the system generates a unique, real-time claim code (e.g., `FB-1042`), locking down those portions securely so they can head over to the non-profit for a dignified pickup.

## How we built it
We engineered this platform using a cutting-edge, emerging tech stack anchored around data-spatial graph principles:

*   **Language & Architecture (Jac):** The core backend and client-side page routing are entirely written in **Jac**, an autonomous, agent-oriented programming language. We leveraged Jac's native architecture—using **Nodes** to construct data hierarchies (`Profile`, `Organization`, `Donation`, `Reservation`) and **Walkers** to act as independent execution agents executing operations over the graph.
*   **Vision AI Subsystem (via Jac's byLLM):** Integrated into our Jac server using the `byllm` library. It binds a vision-capable language model (`groq/qwen/qwen3.8-27b`) to look at uploaded data URLs, enforcing strict semantic schemas (`FoodAnalysis` and `NutritionEstimate`) to cleanly deliver structured responses without inventing facts.
*   **Frontend & Styling:** Built out natively reactive UI components utilizing JSX elements mapped directly through Jac compiler definitions. We injected a cozy, paper-textured, warm neutral CSS aesthetic to give the application an approachable, neighborly, handwritten aesthetic that builds digital trust.
*   **Tooling:** Managed compiling with the `jac` CLI (`jac start --dev main.jac`), incorporating hot-reloading dev instances alongside a headless browser environment (`jac browse`) for rapid UI validation and testing.

## Challenges we ran into
*   **The Jac & JSX Syntax Paradigm Shift:** Navigating Jac's evolving syntax, which creatively bridges aspects of Pythonic control flow with JSX declarative templates, meant a steep learning curve. Early on, standard JavaScript array methods like `.map()` inside comprehensions would break the compiler pipeline, forcing us to rethink how we looped over dynamic file lists using pure primitive iteration counts.
*   **LLM Hallucination Boundaries:** Initial iterations of the Vision AI would confidently hallucinate administrative metadata, inventing pickup hours, available quantities, or non-existent organization names. We had to strictly constrain the model using precise semantic anchoring (`sem`) to force it to stick exclusively to food facts visible in the image.
*   **Session Management Glitches:** We hit a tricky issue where stale tokens from older sessions would cause subsequent signups or private graph walkers (like `GetProfile`) to 401-abort and trigger perpetual reloads. We solved this by baking explicit `jacLogout()` resets and hard window resets straight into our login/signup auth cascades.

## Accomplishments that we're proud of
*   **True Graph Isolation:** Designing an authentic multi-tenant graph architecture where every user type gets an isolated root node at signup. Data nodes stay securely sandboxed underneath individual owner roots, and only explicit global actions compile into cross-user exposures using runtime `grant()` permissions.
*   **Optimistic Concurrency Controls:** Handcrafting real-time serving allocation math. The system dynamically tracks `active_reserved` loops across public roots, effectively shielding community fridges from double-claiming races without lagging the user experience.
*   **A Beautiful, Cohesive UI:** Escaping the sea of modern, sterile Tailwind templates to create a customized bulletin board vibe featuring playful mascot plates and hand-drawn animations.

## What we learned
*   **Agentic Power:** We learned that treating API endpoints as data-walking agents rather than rigid REST controllers allows for incredibly flexible business logic. A walker can naturally pivot its path depending on what node it targets.
*   **AI as a Companion, Not a Master:** Building a reliable system means treating AI data as an *estimate*. By explicitly rendering the AI data inside a collapsing disclosure element (`<details>`) and providing textareas for donors to correct the AI's math, we blended machine learning speed with human precision.

## What's next for Find-My-Food
*   **Push Notification Webhooks:** Integrate live SMS alerts or email pushes to immediately notify neighbors when an intermediary approves a hot meal nearby.
*   **Geospatial Range Calculations:** Incorporate a radius search module to allow college student donors to find the absolute closest physical drop-off bin or pantry relative to their dorm or apartment.
*   **Predictive Logistics:** Train predictive algorithms on historical donation data to help intermediaries forecast which days of the week they are likely to encounter capacity strain or surplus foot traffic.

***

### 🚀 Developer Setup Reference
To fire up the dev environment or step through the compiler guides:
```bash
# List available guides and view core sheets
jac guide jac-core-cheatsheet

# Start the full-stack PlateMate app with hot-reloading
jac start --dev main.jac
```
