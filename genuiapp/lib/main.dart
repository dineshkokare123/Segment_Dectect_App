import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; 
import 'package:webview_flutter/webview_flutter.dart'; 


const String _apiKey = 'AIzaSyCdxODEYKEWtQln4YM1NW9Cw9U8i5QaQuk'; 

// The default placeholder YouTube video ID if the AI fails to find a specific link.
const String _placeholderVideoId = '8v3qM4rD8hQ'; // Generic cooking tips video.

// --- RECIPE DATA MODEL ---
class Recipe {
  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final String videoId; 

  Recipe({
    required this.title,
    required this.ingredients,
    required this.steps,
    required this.videoId,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final ingredients = (json['ingredients'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final steps = (json['steps'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    
    // The model should return a full YouTube URL
    String url = json['videoUrl'] as String? ?? '';
    String id = _placeholderVideoId; // Default to placeholder

    if (url.isNotEmpty) {
      // Use utility function to extract the ID from the full URL.
      id = YoutubePlayer.convertUrlToId(url) ?? _placeholderVideoId;
    }

    return Recipe(
      title: json['title'] ?? 'Unknown Recipe',
      ingredients: ingredients,
      steps: steps,
      videoId: id,
    );
  }
}

// --- MAIN WIDGETS ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 

  runApp(const RecipeGeneratorApp());
}

class RecipeGeneratorApp extends StatelessWidget {
  const RecipeGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Recipe Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const RecipeGeneratorScreen(),
    );
  }
}

class RecipeGeneratorScreen extends StatefulWidget {
  const RecipeGeneratorScreen({super.key});

  @override
  State<RecipeGeneratorScreen> createState() => _RecipeGeneratorScreenState();
}

class _RecipeGeneratorScreenState extends State<RecipeGeneratorScreen> {
  final TextEditingController _promptController = TextEditingController();
  
  // Initialize the Generative Model
  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: _apiKey, 
  );
  
  Recipe? _currentRecipe;
  bool _isLoading = false;
  String? _errorMessage;
  String? _videoErrorMessage; 

  // YouTube Player Controller
  YoutubePlayerController? _youtubeController;
  
  // --- VIDEO LOGIC ---

  @override
  void dispose() {
    _youtubeController?.dispose(); 
    _promptController.dispose();
    super.dispose();
  }

  // Helper to initialize the YouTube player (using videoId)
  void _initializeYoutubePlayer(String videoId) {
    _youtubeController?.dispose();
    _videoErrorMessage = null;

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: true,
        hideControls: false,
      ),
    )..addListener(_videoListener); // Add listener for error handling

    if(mounted) {
      setState(() {}); 
    }
  }
  
  // Video Listener to catch non-embeddable videos (Error Code 150)
  void _videoListener() {
    if (_youtubeController != null && _youtubeController!.value.hasError) {
      // YouTube Player Error. Error 150 is "Playback disabled on other websites"
      if (_youtubeController!.value.errorCode == 150) {
        if (_videoErrorMessage == null) { // Only update state once
          setState(() {
            _videoErrorMessage = 'This video cannot be embedded. The owner has restricted playback on other websites. Please try generating a different recipe, or refresh for the general cooking video.';
          });
          _youtubeController?.pause(); 
        }
      } else if (_youtubeController!.value.errorCode != 0) {
        // Handle other errors (like invalid ID)
         if (_videoErrorMessage == null) {
          setState(() {
            _videoErrorMessage = 'Video playback error: Code ${_youtubeController!.value.errorCode}. The video ID might be invalid.';
          });
        }
      }
    }
  }


  // --- GEMINI API LOGIC ---

  Future<void> _generateRecipe() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _videoErrorMessage = null; 
      _currentRecipe = null;
      _youtubeController?.dispose(); 
      _youtubeController = null;
    });

    try {
      final instructionText = '''
        You are a world-class chef AI. Generate a detailed recipe based on the user's request.
        The response MUST be a valid JSON string that adheres strictly to the following schema:
        {
          "title": "Recipe Name",
          "ingredients": ["List of ingredients"],
          "steps": ["Step 1", "Step 2"],
          "videoUrl": "A full, public YouTube URL for a high-quality, relevant video demonstration of the final recipe. 
          
          ***CRITICAL INSTRUCTION***: You MUST ensure the video is ALLOWED TO BE EMBEDDED on third-party sites. If you are not absolutely certain the video is embeddable, or if you cannot find a highly relevant video, use the placeholder URL: https://www.youtube.com/watch?v=8v3qM4rD8hQ. Do NOT provide URLs that are likely to be restricted.
          
          Search term should be: 'Recipe Name tutorial full recipe embeddable'.
          "
        }
        The JSON MUST NOT contain markdown code fences (```json) or any extra text outside the JSON object.
        
        USER RECIPE QUERY: "$prompt"
      ''';

      // Note on Performance: The speed of this call is primarily limited by the network
      // latency and the model's processing time. We use 'gemini-2.5-flash' for speed.
      final response = await _model.generateContent([
        Content.text(instructionText),
      ]);

      if (!mounted) return;

      final jsonString = response.text ?? '';
      
      // Clean the response string from markdown fences and trim
      String cleanedJson = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
      
      // NEW: Aggressively remove control characters and non-standard spaces
      // This targets non-breaking spaces (U+00A0) and other invisible characters that break JSON parsing.
      cleanedJson = cleanedJson.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F\u00A0\u200B-\u200F\uFEFF]'), '');
      
      // Parse the clean JSON string into a Dart Map
      final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson);

      // Create the Recipe object from the parsed map
      final recipeData = Recipe.fromJson(jsonMap);

      // Initialize the YouTube player with the extracted video ID
      _initializeYoutubePlayer(recipeData.videoId);

      if (!mounted) return;
      
      setState(() {
        _currentRecipe = recipeData;
      });
      
    } on GenerativeAIException catch (e) {
      if (mounted) {
        // Catches API errors like the 503 "The model is overloaded."
        setState(() {
          _errorMessage = 'API Error (Generative AI): ${e.message}. Please wait a moment and try again.';
        });
      }
      debugPrint('API Error: $e');
    } on FormatException catch (e) {
      if (mounted) {
        // Catches JSON parsing errors. The new cleaning step should reduce this.
        setState(() {
          _errorMessage = 'Data Error: The model returned a malformed recipe structure. Please try generating the recipe again.';
        });
      }
      debugPrint('API Error (FormatException): $e');
    } catch (e) {
      if (mounted) {
        // Catches any other unexpected errors
        setState(() {
          _errorMessage = 'An unexpected error occurred: $e';
        });
      }
      debugPrint('API Error (Unknown): $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- UI BUILDER ---

  // Widget to display the YouTube player or a placeholder
  Widget _buildVideoWidget(BuildContext context) {
    if (_youtubeController == null) {
      // Show loading/placeholder state while video initializes
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_camera_back, size: 50, color: Colors.grey),
              Text('Video Loading...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    // Check for specific video error messages
    if (_videoErrorMessage != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade300)
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _videoErrorMessage!, 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );
    }

    // Returns the YoutubePlayer widget, wrapped for stability
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      // Added RepaintBoundary for stability on native views (iOS WebView)
      child: RepaintBoundary(
        child: YoutubePlayer(
          // Added ValueKey to force the native view to be completely rebuilt 
          key: ValueKey(_youtubeController!.initialVideoId), 
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Theme.of(context).colorScheme.primary,
          // Explicitly use WebView mode if possible to leverage the
          // stability improvements set up in main()
          aspectRatio: 16/9, // Use aspect ratio here for completeness
          onReady: () {
            // Player is ready
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Recipe Master'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // Center and constrain the content for better responsiveness on large screens
      body: Center( 
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700.0), // Max width limit
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Input Field
                TextField(
                  controller: _promptController,
                  decoration: const InputDecoration(
                    labelText: 'e.g., "A quick vegan curry with chickpeas" or "Chocolate Lava Cake"',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _generateRecipe(),
                ),
                const SizedBox(height: 16),
                
                // Generate Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generateRecipe,
                  icon: const Icon(Icons.lunch_dining),
                  label: Text(_isLoading ? 'Generating...' : 'Get Recipe'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Loading Indicator / Error Message
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),

                // Recipe Display: Using extracted widget for cleaner code
                if (_currentRecipe != null) 
                  _RecipeDetailsCard(
                    recipe: _currentRecipe!,
                    buildVideoWidget: _buildVideoWidget,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Extracted Widget for Recipe Details to clean up the main build method
class _RecipeDetailsCard extends StatelessWidget {
  final Recipe recipe;
  // This is a function reference passed from the parent state
  final Widget Function(BuildContext) buildVideoWidget; 

  const _RecipeDetailsCard({
    required this.recipe,
    required this.buildVideoWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Video Player UI
        const Text('Instructional Video', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 2.0)),
        AspectRatio(
            aspectRatio: 16 / 9,
            child: buildVideoWidget(context),
        ),
        const SizedBox(height: 24),

        // Recipe Details
        Text(
          recipe.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade700),
        ),
        const Divider(color: Colors.deepOrange),
        
        // Ingredients
        const Text('Ingredients', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 2.0)),
        ...recipe.ingredients.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
          child: Text('• $item'),
        )),

        // Steps
        const Text('Instructions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 2.0)),
        ...recipe.steps.asMap().entries.map((entry) {
          int index = entry.key;
          String step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.deepOrange.shade100,
                  foregroundColor: Colors.deepOrange.shade700,
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(step)),
              ],
            ),
          );
        }),
      ],
    );
  }
}