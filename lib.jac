"""FreeBuff shared library - AI model config and photo-analysis schemas.

Included by endpoints.sv.jac; never reaches the client bundle.
"""

import os;
import from datetime { datetime }
import from byllm.lib { Model, Image }

# Vision-capable model for food photo analysis. Override with the
# BYLLM_DEFAULT_MODEL environment variable (any LiteLLM model string).
glob llm = Model(
    model_name=os.environ.get(
        "BYLLM_DEFAULT_MODEL",
        "groq/qwen/qwen3.8-27b"
    )
);

"""Photo payload handed to the vision model."""
obj FoodPhoto {
    has data: Image;
}

"""Per-serving nutrition estimates; every field is hedged, never precise."""
obj NutritionEstimate {
    has calories: str,
        protein: str,
        carbohydrates: str,
        fat: str;
}

sem NutritionEstimate.calories = "e.g. '~430 kcal', or 'Unable to reliably estimate from image'";
sem NutritionEstimate.protein = "e.g. '~28 g', or 'Unable to reliably estimate from image'";
sem NutritionEstimate.carbohydrates = "e.g. '~52 g', or 'Unable to reliably estimate from image'";
sem NutritionEstimate.fat = "e.g. '~14 g', or 'Unable to reliably estimate from image'";

"""Structured AI result: ONLY these three categories, nothing else."""
obj FoodAnalysis {
    has ingredients: list[str],
        serving_size: str,
        nutrition: NutritionEstimate;
}

sem FoodPhoto.data = "A donor's phone photo of prepared food they want to donate";
sem FoodAnalysis.ingredients = "Approximate visible or likely ingredients, lower case, 3 to 8 short strings; use 'Unknown' for anything not identifiable";
sem FoodAnalysis.serving_size = "Estimated amount per person such as '~1.5 cups', or 'Unable to determine from image'";
sem FoodAnalysis.nutrition = "Per-serving nutrition estimates";

"""The AI's ONLY job: photo -> ingredients + serving size + nutrition.

The image must be a direct function argument: byLLM lifts bare Media args
into proper image_url content blocks. Wrapping Media inside an obj breaks
that path on this version (the model receives only the obj repr and, true
to its instructions, answers 'Unknown' rather than inventing facts).
"""
def analyze_food_photo(photo_image: Image, what: str) -> FoodAnalysis by llm();

sem analyze_food_photo = "You are a careful food analyst for a community food sharing platform. Look at the photo of donated food and estimate ONLY: approximate ingredients, serving size per person, and nutrition per serving. Never invent information you cannot see; hedge estimates with '~'. Write 'Unknown' for any ingredient you cannot identify and 'Unable to reliably estimate from image' for any nutrition value you cannot judge. Never output organization, pickup, servings, price, donor, reservation or availability information - those are application fields, not photo facts.";

# ---------------------------------------------------------------- helpers --

def now_iso -> str {
    return datetime.now().isoformat(timespec="seconds");
}


"""Resolve any node by id; returns None when absent or unreadable."""
def get_node(node_id: str) -> any {
    if not node_id {
        return None;
    }
    try {
        return jobj(node_id);
    } except Exception {
        return None;
    }
}
