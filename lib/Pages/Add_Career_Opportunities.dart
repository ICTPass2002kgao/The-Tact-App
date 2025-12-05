import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:ttact/Components/API.dart'; // Ensure this path matches your project

class AddCareerOpportunities extends StatefulWidget {
  const AddCareerOpportunities({super.key});

  @override
  State<AddCareerOpportunities> createState() => _AddCareerOpportunitiesState();
}

class _AddCareerOpportunitiesState extends State<AddCareerOpportunities> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- State Variables for Logic ---
  String? _editingId; // If null, we are adding. If set, we are updating.
  String? _existingImageUrl; // To show image from DB when editing
  bool _isLoading = false;

  // --- Controllers (Standard) ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // --- Controllers (Contact & Physical) ---
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // --- Controllers (Single Field Details) ---
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _financialController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // --- Controllers (Dynamic Lists) ---
  final TextEditingController _reqInputController = TextEditingController();
  final TextEditingController _dutyInputController = TextEditingController();
  final TextEditingController _courseInputController = TextEditingController();
  final TextEditingController _customDocController = TextEditingController();

  // --- Lists Data ---
  List<String> _requirementsList = [];
  List<String> _dutiesList = [];
  List<String> _coursesList = [];
  List<String> _customDocumentsList = [];

  // --- File & Date State ---
  File? _imageFile;
  DateTime? _expiryDate;
  String _selectedCategory = 'Bursary';

  final List<String> _categories = [
    'Bursary', 'Scholarship', 'Internship', 'Job', 'Learnership',
  ];

  // Standard Document Defaults
  final Map<String, List<String>> _defaultDocsByCategory = {
    'Bursary': ['Certified ID Copy', 'Matric Certificate/Results', 'Full Academic Record', 'Proof of Residence', 'Proof of income'],
    'Scholarship': ['Certified ID Copy', 'Full Academic Record', 'Motivation Letter', 'Curriculum Vitae (CV)'],
    'Internship': ['Curriculum Vitae (CV)', 'Certified ID Copy', 'Full Academic Record', 'Letter from Institution'],
    'Job': ['Curriculum Vitae (CV)', 'Certified ID Copy', 'Matric Certificate/Results'],
    'Learnership': ['Curriculum Vitae (CV)', 'Certified ID Copy', 'Matric Certificate/Results', 'Proof of Residence'],
  };

  final List<String> _commonDocuments = [
    'Certified ID Copy',
    'Curriculum Vitae (CV)',
    'Matric Certificate/Results',
    'Full Academic Record',
    'Proof of Residence',
    'Motivation Letter',
    'Parents/Guardians Proof of Income',
    'Proof of Registration',
    '3 Months Bank Statements',
    'Letter from Institution',
    'Driver\'s License',
  ];

  List<String> _selectedStandardDocuments = [];

  final List<String> _bursaryBenefitsOptions = [
    'Tuition Fees', 'Accommodation', 'Meals', 'Textbooks', 'Laptop', 'Monthly Allowance', 'Transport',
  ];
  final List<String> _selectedBenefits = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedStandardDocuments = List.from(_defaultDocsByCategory['Bursary']!);
    
    // Listen to tab changes to clear form if user manually switches to "Add"
    _tabController.addListener(() {
      if (_tabController.index == 0 && _tabController.previousIndex == 1 && !_tabController.indexIsChanging) {
         // Optional: Clear form if you want them to start fresh when clicking "Post New"
         // _clearForm(); 
      }
    });
  }

  // --- Logic: Populate Form for Editing ---
  void _populateFormForEditing(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    Map<String, dynamic> details = data['details'] ?? {};

    setState(() {
      _editingId = doc.id;
      _selectedCategory = data['category'] ?? 'Bursary';
      _titleController.text = data['title'] ?? '';
      _linkController.text = data['link'] ?? '';
      _emailController.text = data['applicationEmail'] ?? '';
      _existingImageUrl = data['imageUrl'];
      
      // Handle Date
      if (data['expiryDate'] != null) {
        _expiryDate = (data['expiryDate'] as Timestamp).toDate();
      } else {
        _expiryDate = null;
      }

      // Handle Docs (We separate standard from custom purely by checking existence in our hardcoded list)
      List<dynamic> allDocs = data['requiredDocuments'] ?? [];
      _selectedStandardDocuments.clear();
      _customDocumentsList.clear();
      
      for (var d in allDocs) {
        if (_commonDocuments.contains(d) || _defaultDocsByCategory.values.any((list) => list.contains(d))) {
          if(!_selectedStandardDocuments.contains(d)) _selectedStandardDocuments.add(d.toString());
        } else {
          _customDocumentsList.add(d.toString());
        }
      }

      // Details
      _subtitleController.text = details['subtitle'] ?? '';
      _financialController.text = details['financial'] ?? '';
      _durationController.text = details['duration'] ?? '';
      _locationController.text = details['location'] ?? '';
      _addressController.text = details['address'] ?? '';
      _phoneController.text = details['contactNumber'] ?? '';

      // Lists
      _selectedBenefits.clear();
      if (details['benefits'] != null) {
        _selectedBenefits.addAll(List<String>.from(details['benefits']));
      }

      _requirementsList = List<String>.from(details['requirementsList'] ?? []);
      _dutiesList = List<String>.from(details['dutiesList'] ?? []);
      _coursesList = List<String>.from(details['coursesList'] ?? []);

      // Switch Tab
      _tabController.animateTo(0);
    });
  }

  // --- Logic: Category Changed ---
  void _onCategoryChanged(String newCategory) {
    setState(() {
      _selectedCategory = newCategory;
      // Only reset defaults if we are NOT editing, or user explicitly wants to reset
      if (_editingId == null) {
        _selectedStandardDocuments = List.from(_defaultDocsByCategory[newCategory] ?? []);
        _selectedBenefits.clear();
      }
    });
  }

  // --- Logic: Add/Remove List Items ---
  void _addItemToList(TextEditingController controller, List<String> targetList) {
    if (controller.text.trim().isNotEmpty) {
      setState(() {
        targetList.add(controller.text.trim());
        controller.clear();
      });
    }
  }

  void _removeItemFromList(String item, List<String> targetList) {
    setState(() {
      targetList.remove(item);
    });
  }

  // --- Logic: Pick Image ---
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  // --- Logic: Toggles ---
  void _toggleStandardDoc(String doc) {
    setState(() {
      _selectedStandardDocuments.contains(doc)
          ? _selectedStandardDocuments.remove(doc)
          : _selectedStandardDocuments.add(doc);
    });
  }

  void _toggleBenefit(String benefit) {
    setState(() {
      _selectedBenefits.contains(benefit)
          ? _selectedBenefits.remove(benefit)
          : _selectedBenefits.add(benefit);
    });
  }

  // --- Logic: Upload / Update ---
  Future<void> _submitData() async {
    if (_titleController.text.isEmpty) {
      _showPlatformAlert("Missing Info", "Title is required.");
      return;
    }

    // Combine Standard + Custom Docs
    List<String> finalDocs = [..._selectedStandardDocuments, ..._customDocumentsList];

    setState(() => _isLoading = true);

    try {
      String imageUrl = _existingImageUrl ?? "";
      
      // If a NEW file is picked, upload it and overwrite the URL
      if (_imageFile != null) {
        String fileName = path.basename(_imageFile!.path);
        // Add timestamp to filename to prevent caching issues on updates
        String uniqueName = "${DateTime.now().millisecondsSinceEpoch}_$fileName";
        Reference ref = FirebaseStorage.instance.ref().child('career_images/$uniqueName');
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      Map<String, dynamic> specificDetails = {
        'subtitle': _subtitleController.text.trim(),
        'financial': _financialController.text.trim(),
        'duration': _durationController.text.trim(),
        'location': _locationController.text.trim(),
        'benefits': _selectedBenefits,
        'requirementsList': _requirementsList,
        'dutiesList': _dutiesList,
        'coursesList': _coursesList,
        'address': _addressController.text.trim(),
        'contactNumber': _phoneController.text.trim(),
      };

      Map<String, dynamic> mainData = {
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'link': _linkController.text.trim(),
        'applicationEmail': _emailController.text.trim(),
        'imageUrl': imageUrl,
        'requiredDocuments': finalDocs,
        'details': specificDetails,
        'expiryDate': _expiryDate != null ? Timestamp.fromDate(_expiryDate!) : null,
        // Only update 'createdAt' if it's new, otherwise keep original or add 'updatedAt'
        'isActive': true,
      };

      if (_editingId != null) {
        // UPDATE Existing
        mainData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('career_opportunities').doc(_editingId).update(mainData);
        if (mounted) _showPlatformAlert("Success", "Opportunity Updated Successfully!");
      } else {
        // CREATE New
        mainData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('career_opportunities').add(mainData);
        if (mounted) _showPlatformAlert("Success", "Opportunity Published!");
      }

      if (mounted) {
        _clearForm();
      }
    } catch (e) {
      if (mounted) _showPlatformAlert("Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _linkController.clear();
    _emailController.clear();
    _addressController.clear();
    _phoneController.clear();
    _subtitleController.clear();
    _financialController.clear();
    _durationController.clear();
    _locationController.clear();

    _reqInputController.clear();
    _dutyInputController.clear();
    _courseInputController.clear();
    _customDocController.clear();

    setState(() {
      _editingId = null; // Reset to "Add Mode"
      _existingImageUrl = null;
      _imageFile = null;
      _expiryDate = null;
      _selectedCategory = 'Bursary';
      _selectedStandardDocuments = List.from(_defaultDocsByCategory['Bursary']!);
      _selectedBenefits.clear();
      _requirementsList.clear();
      _dutiesList.clear();
      _coursesList.clear();
      _customDocumentsList.clear();
    });
  }

  Future<void> _deleteOpportunity(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('career_opportunities').doc(docId).delete();
      _showPlatformAlert("Deleted", "Opportunity removed.");
    } catch (e) {
      _showPlatformAlert("Error", "Could not delete: $e");
    }
  }

  void _showPlatformAlert(String title, String message) {
    Api().showMessage(context, message, title, _editingId != null ? Colors.blue : Colors.green);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow past dates if editing old stuff
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Career Center"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.add_box), text: "Post / Edit"),
            Tab(icon: Icon(Icons.list), text: "Manage All"),
          ],
        ),
        actions: [
          if (_editingId != null)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: "Cancel Edit",
              onPressed: _clearForm,
            )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: FORM
          _buildFormTab(isIos, primaryColor),
          
          // TAB 2: LIST
          _buildListTab(primaryColor),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: The Form (Existing Logic)
  // ==========================================
  Widget _buildFormTab(bool isIos, Color primaryColor) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator.adaptive())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editingId != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 15),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.blue),
                        const SizedBox(width: 10),
                        const Expanded(child: Text("You are in Edit Mode. Changes will update the existing entry.", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                        TextButton(onPressed: _clearForm, child: const Text("Cancel"))
                      ],
                    ),
                  ),

                // 1. Image Banner
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: _imageFile != null
                          ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                          : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                              ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                              : null,
                    ),
                    child: (_imageFile == null && _existingImageUrl == null)
                        ? Center(child: Icon(Icons.add_a_photo, size: 40, color: Colors.grey[400]))
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: Text(_imageFile == null && _existingImageUrl != null ? "Tap to change existing image" : "Tap to upload image", style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                const SizedBox(height: 20),

                // 2. Category Selector
                Text("Category", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: primaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? primaryColor : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                          ),
                          onSelected: (val) {
                            if (val) _onCategoryChanged(cat);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Main Title
                _buildPlatformTextField(
                  controller: _titleController,
                  placeholder: _getLabelForTitle(),
                  icon: Icons.title,
                  isIos: isIos,
                ),
                const SizedBox(height: 16),

                // 4. Expiry Date (Optional)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _expiryDate == null ? "Open / No Closing Date" : "Closes: ${DateFormat('yyyy-MM-dd').format(_expiryDate!)}",
                        style: TextStyle(color: _expiryDate == null ? Colors.green : Colors.black, fontWeight: _expiryDate == null ? FontWeight.bold : FontWeight.normal),
                      ),
                      Row(
                        children: [
                          if (_expiryDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () => setState(() => _expiryDate = null), // Clear date
                            ),
                          IconButton(
                            icon: Icon(Icons.calendar_today, color: primaryColor),
                            onPressed: () => _selectDate(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Dynamic Fields
                ..._buildCategorySpecificFields(isIos, primaryColor),

                // 6. Application Method & Contact
                const SizedBox(height: 20),
                Text("Application & Contact Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(child: _buildPlatformTextField(controller: _linkController, placeholder: "Web Link", icon: Icons.link, isIos: isIos)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildPlatformTextField(controller: _emailController, placeholder: "App/Contact Email", icon: Icons.email, isIos: isIos)),
                  ],
                ),
                const SizedBox(height: 10),

                _buildPlatformTextField(
                  controller: _addressController,
                  placeholder: "Physical Address (For drop-offs)",
                  icon: Icons.map,
                  isIos: isIos
                ),
                const SizedBox(height: 10),
                _buildPlatformTextField(
                  controller: _phoneController,
                  placeholder: "Contact Number (Optional)",
                  icon: Icons.phone,
                  isIos: isIos,
                  keyboardType: TextInputType.phone
                ),

                // 7. Documents Checklist
                const SizedBox(height: 20),
                Text("Required Documents", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: _commonDocuments.map((doc) {
                    final isSelected = _selectedStandardDocuments.contains(doc);
                    return FilterChip(
                      label: Text(doc),
                      selected: isSelected,
                      onSelected: (_) => _toggleStandardDoc(doc),
                      checkmarkColor: primaryColor,
                      selectedColor: primaryColor.withOpacity(0.15),
                      labelStyle: TextStyle(color: isSelected ? primaryColor : Colors.black, fontSize: 11),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                _buildDynamicListSection(
                  title: "Add Custom Documents (One by one)",
                  placeholder: "e.g. Skipper License",
                  controller: _customDocController,
                  targetList: _customDocumentsList,
                  isIos: isIos,
                  primaryColor: primaryColor
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _editingId != null ? Colors.blue : primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitData,
                    child: Text(
                      _editingId != null ? "Update Opportunity" : "Publish Opportunity",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
  }

  // ==========================================
  // TAB 2: Manage List
  // ==========================================
  Widget _buildListTab(Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('career_opportunities')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading data"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No opportunities posted yet."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            // Format Expiry
            String expiryText = "Open / Ongoing";
            bool isExpired = false;
            if (data['expiryDate'] != null) {
              DateTime exp = (data['expiryDate'] as Timestamp).toDate();
              expiryText = DateFormat('dd MMM yyyy').format(exp);
              if (exp.isBefore(DateTime.now())) isExpired = true;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        image: (data['imageUrl'] != null && data['imageUrl'] != "") 
                          ? DecorationImage(image: NetworkImage(data['imageUrl']), fit: BoxFit.cover)
                          : null
                      ),
                      child: (data['imageUrl'] == null || data['imageUrl'] == "") ? const Icon(Icons.work) : null,
                    ),
                    title: Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text("${data['category']}  •  Expires: $expiryText", 
                          style: TextStyle(color: isExpired ? Colors.red : Colors.grey[700], fontSize: 12)
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _populateFormForEditing(doc);
                        } else if (value == 'delete') {
                          _deleteOpportunity(doc.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text("Edit & Renew")])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Helper: Dynamic Labels ---
  String _getLabelForTitle() {
    switch (_selectedCategory) {
      case 'Job': return "Job Title";
      case 'Internship': return "Role Title";
      case 'Learnership': return "Programme Name";
      default: return "Opportunity Title";
    }
  }

  // --- Helper: Dynamic Fields Builder ---
  List<Widget> _buildCategorySpecificFields(bool isIos, Color primaryColor) {
    List<Widget> fields = [];

    // -- Subtitle --
    if (_selectedCategory == 'Bursary' || _selectedCategory == 'Scholarship') {
       fields.add(_buildDynamicListSection(
         title: "Courses / Fields of Study",
         placeholder: "Add field (e.g. Engineering)",
         controller: _courseInputController,
         targetList: _coursesList,
         isIos: isIos,
         primaryColor: primaryColor
       ));
    } else {
       String subPlace = _selectedCategory == 'Learnership' ? "Qualification Level (e.g. NQF 4)" : "Company Name";
       fields.add(_buildPlatformTextField(controller: _subtitleController, placeholder: subPlace, icon: Icons.business, isIos: isIos));
    }
    fields.add(const SizedBox(height: 16));

    // -- Financials --
    if (_selectedCategory != 'Bursary' && _selectedCategory != 'Scholarship') {
      fields.add(Row(
        children: [
           Expanded(child: _buildPlatformTextField(controller: _financialController, placeholder: _selectedCategory == 'Job' ? "Salary" : "Stipend", icon: Icons.money, isIos: isIos)),
           const SizedBox(width: 10),
           Expanded(child: _buildPlatformTextField(controller: _locationController, placeholder: "Location", icon: Icons.location_on, isIos: isIos)),
        ],
      ));
       fields.add(const SizedBox(height: 16));
    }

    // -- Requirements --
    fields.add(_buildDynamicListSection(
         title: "Requirements",
         placeholder: "Add requirement...",
         controller: _reqInputController,
         targetList: _requirementsList,
         isIos: isIos,
         primaryColor: primaryColor
    ));
    fields.add(const SizedBox(height: 16));

    // -- Benefits (Bursary Only) --
    if (_selectedCategory == 'Bursary' || _selectedCategory == 'Scholarship') {
      fields.add(Text("What it Covers", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])));
      fields.add(Wrap(
        spacing: 6,
        children: _bursaryBenefitsOptions.map((benefit) {
          final isSelected = _selectedBenefits.contains(benefit);
          return FilterChip(
            label: Text(benefit),
            selected: isSelected,
            onSelected: (_) => _toggleBenefit(benefit),
            selectedColor: Colors.green.withOpacity(0.2),
            checkmarkColor: Colors.green,
            labelStyle: TextStyle(fontSize: 11, color: isSelected ? Colors.green[800] : Colors.black),
          );
        }).toList(),
      ));
      fields.add(const SizedBox(height: 16));
    }

    // -- Duration --
    if (_selectedCategory == 'Internship' || _selectedCategory == 'Learnership' || _selectedCategory == 'Bursary') {
      fields.add(_buildPlatformTextField(
        controller: _durationController,
        placeholder: "Duration / Contract",
        icon: Icons.timer,
        isIos: isIos
      ));
      fields.add(const SizedBox(height: 16));
    }

    // -- Description / Duties --
    String dutyTitle = "Duties / Responsibilities";
    if(_selectedCategory == 'Learnership') dutyTitle = "Modules / Syllabus";
    if(_selectedCategory == 'Bursary') dutyTitle = "Additional Info";

    fields.add(_buildDynamicListSection(
         title: dutyTitle,
         placeholder: "Add item...",
         controller: _dutyInputController,
         targetList: _dutiesList,
         isIos: isIos,
         primaryColor: primaryColor
    ));

    return fields;
  }

  Widget _buildDynamicListSection({
    required String title,
    required String placeholder,
    required TextEditingController controller,
    required List<String> targetList,
    required bool isIos,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildPlatformTextField(
                controller: controller,
                placeholder: placeholder,
                icon: Icons.add_circle_outline,
                isIos: isIos
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _addItemToList(controller, targetList),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        if (targetList.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!)
            ),
            child: Column(
              children: targetList.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                      InkWell(
                        onTap: () => _removeItemFromList(item, targetList),
                        child: Icon(Icons.close, size: 16, color: Colors.red[300]),
                      )
                    ],
                  ),
                );
              }).toList(),
            ),
          )
      ],
    );
  }

  Widget _buildPlatformTextField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    required bool isIos,
    TextInputType keyboardType = TextInputType.text,
  }) {
    if (isIos) {
      return CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        padding: const EdgeInsets.all(14),
        keyboardType: keyboardType,
        prefix: Padding(padding: const EdgeInsets.only(left: 12.0), child: Icon(icon, color: CupertinoColors.systemGrey, size: 20)),
        decoration: BoxDecoration(border: Border.all(color: CupertinoColors.systemGrey4), borderRadius: BorderRadius.circular(8)),
      );
    } else {
      return TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: placeholder,
          prefixIcon: Icon(icon, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      );
    }
  }
}