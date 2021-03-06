import 'dart:io';
import 'dart:ui';

import 'package:analog_clock/analog_clock.dart';
import 'package:another_quickbase/another_quickbase.dart';
import 'package:another_quickbase/another_quickbase_models.dart';
import 'package:day/day.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

//import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:air_brother/air_brother.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:universal_platform/universal_platform.dart';
import 'dart:math' as math;

import 'app_keys.dart';
import 'event_notifier.dart';

const double kLabelWidth = 90.3;
const double kLabelHeight = 29;
const double kDefaultRatePerHour = 60.0;
LottieComposition? kDefaultComposition;

TextStyle kLabelTextStyle = GoogleFonts.vibur();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  final bool isDark = false;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Howzie Keanu',
      theme: toThemeData(),
      home: const MyHomePage(title: 'Howzie Keanu'),
    );
  }

  ThemeData toThemeData() {
    var accent1 = const Color(0xFFfec89a);
    var bg1 = const Color(0xFF4cc9f0);
    var surface1 = const Color(0xfffec89a); //Colors.white;
    var mainTextColor = isDark ? Colors.white : Colors.black;
    var greyStrong = const Color(0xFF131A22);
    var inverseTextColor = !isDark ? Colors.black : Colors.white;
    //var focus = const Color(0xFF4ac3be);
    var grey = const Color(0xff999999);
    var textTheme = (!isDark ? ThemeData.dark() : ThemeData.light()).textTheme;
    ColorScheme scheme = ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent1,
        secondary: accent1,
        background: bg1,
        surface: surface1,
        onBackground: mainTextColor,
        onSurface: mainTextColor,
        onError: mainTextColor,
        onPrimary: greyStrong,
        onSecondary: inverseTextColor,
        error: Colors.black);

    var t = ThemeData.from(
      // Use the .dark() and .light() constructors to handle the text themes
        textTheme: _buildTextTheme(textTheme),
        // Use ColorScheme to generate the bulk of the color theme
        colorScheme: scheme);

    t = t.copyWith(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        primaryIconTheme: const IconThemeData(
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            filled: true,
            fillColor: surface1,
            labelStyle: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.black.withAlpha(200),
            ),
            focusedErrorBorder:
            OutlineInputBorder(borderSide: BorderSide(color: accent1)),
            focusedBorder:
            OutlineInputBorder(borderSide: BorderSide(color: accent1)),
            errorBorder:
            OutlineInputBorder(borderSide: BorderSide(color: accent1)),
            enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: greyStrong))),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: grey,
          selectionHandleColor: Colors.transparent,
          selectionColor: grey,
        ),
        snackBarTheme: t.snackBarTheme.copyWith(
            backgroundColor: accent1,
            actionTextColor: mainTextColor,
            contentTextStyle:
            t.textTheme.caption!.copyWith(color: mainTextColor)),
        scaffoldBackgroundColor: bg1,
        highlightColor: shift(accent1, .1),
        toggleableActiveColor: accent1,
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(side: BorderSide(color: accent1))));
    // All done, return the ThemeData
    return t;
  }

  /// This will add luminance in dark mode, and remove it in light.
  // Allows the view to just make something "stronger" or "weaker" without worrying what the current theme brightness is
  //      color = theme.shift(someColor, .1); //-10% lum in dark mode, +10% in light mode
  Color shift(Color c, double amt) {
    amt *= (isDark ? -1 : 1);
    var hslc = HSLColor.fromColor(c); // Convert to HSL
    double lightness =
    (hslc.lightness + amt).clamp(0, 1.0) as double; // Add/Remove lightness
    return hslc.withLightness(lightness).toColor(); // Convert back to Color
  }

  TextTheme _buildTextTheme(TextTheme base) {
    return base
        .copyWith(
      bodyText2: GoogleFonts.robotoCondensed(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        //letterSpacing: letterSpacingOrNone(0.5),
      ),
      bodyText1: GoogleFonts.eczar(
        fontSize: 40,
        fontWeight: FontWeight.w400,
        //letterSpacing: letterSpacingOrNone(1.4),
      ),
      button: GoogleFonts.robotoCondensed(
        fontWeight: FontWeight.w700,
        //letterSpacing: letterSpacingOrNone(2.8),
      ),
      headline5: GoogleFonts.eczar(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        //letterSpacing: letterSpacingOrNone(1.4),
      ),
    )
        .apply(
      displayColor: Colors.black,
      bodyColor: Colors.black,
    );
  }

}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with CustomerQuickbase, BrotherScanner, HowzieLogo, UsLicenseNumber {
  int _selectedIndex = 0;
  final int _recordsPerPage = 30;
  final PagingController<int, Customer> _pagingController =
      PagingController(firstPageKey: 0);
  final _formKey = GlobalKey<FormState>();

  Customer? _activeCustomer;
  final ProgressModel _progressModel = ProgressModel(
      status: KeanuStatus.none, message: "Searching for customer...");

  QuickBaseClient client = QuickBaseClient(
      qBRealmHostname: AppKeys.quickbaseRealm,
      appToken: AppKeys.quickbaseAppToken);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);

    // Load the lottie ahead of time so by the time we need it there is no delay.
    rootBundle.load('assets/lottie/van_morphing_animation.json').then((lottieData) => LottieComposition.fromByteData(lottieData).then((composition) => kDefaultComposition = composition));

    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await _fetchCheckedIn(
          client: client, page: pageKey, pageSize: _recordsPerPage);
      final isLastPage = newItems.length < _recordsPerPage;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + newItems.length;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      print("Error: $error");
      _pagingController.error = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HowzieAppBar(
        title: widget.title,
      ),
      body: _buildPage(context: context, page: _selectedIndex),
      floatingActionButton: ExpandableFab(
        mainFabBody: const Icon(Icons.surfing),
        distance: 112.0,
        children: [
          Tooltip(
            message: "Check-In",
            child: ActionButton(
              onPressed: () {
                _checkInCustomer();
              },
              icon: const Icon(Icons.surfing),
            ),
          ),
          Tooltip(
            message: "Check-Out",
            child: ActionButton(
              onPressed: () {
                _performCustomerCheckout();
              },
              icon: const Icon(Icons.time_to_leave_rounded),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPage({required BuildContext context, required int page}) {
    return _buildLargeCheckInView(context);
  }

  Widget _buildLargeCheckInView(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          child: PagedGridView(
              padding: const EdgeInsets.only(left: 16, right: 16),
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<Customer>(
                itemBuilder: (context, item, index) => _generateCheckedInCard(
                    index: index, customer: item, context: context),
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  mainAxisExtent: 300 * kLabelHeight / kLabelWidth,
                  maxCrossAxisExtent: 300,
                  childAspectRatio: kLabelWidth / kLabelHeight)),
        ),
        Positioned(
          child: ChangeNotifierProvider.value(
              value: _progressModel,
              child: Consumer<ProgressModel>(
                builder:
                    (BuildContext context, ProgressModel data, Widget? child) {
                  return ProgressOverlay();
                },
              )),
        )
      ],
    );
  }

  Widget _generateCheckedInCard(
      {required BuildContext context,
      required int index,
      required Customer customer}) {
    // TODO Crate Check-In Card
    return CustomerCheckedInCardView(
      customer: customer,
      onLongPress: () {
        // TODO Open update dialog
      },
      onDeleteTap: () {
        // TODO Consider opening a dialog.
        _performDeleteCustomer(customer: customer);
      },
      onTap: () {
        setState(() {
          customer.isSelected = !customer.isSelected;
        });
      },
    );
  }

  ///
  /// Deletes the specified record from the lessons table.
  ///
  Future<void> _performDeleteCustomer({required Customer customer}) async {
    bool? delete = await _showBaseConfirmationDialogDialog(
      body: RichText(
        text: TextSpan(
          text: 'Delete customer  ',
          style: Theme.of(context).textTheme.bodyText2,
          children: <TextSpan>[
            TextSpan(
                text: "${customer.firstName} ${customer.lastName} ",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: "?"),
          ],
        ),
      ),
      positive: "Delete",
    );

    if (delete != true) {
      return;
    }

    int deletedCount =
        await _deleteCustomer(customer: customer, client: client);

    if (deletedCount > 0) {
      setState(() {
        _pagingController.itemList?.removeWhere(
            (element) => element.licenseNumber == customer.licenseNumber);
      });
    }
  }

  void _showSnackBar({required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
    ));
  }

  ///
  /// Performs the customer check in process.
  /// Process:
  /// - Scan Driver license
  /// - Capture details from driver's license
  /// - Create customer on Quickbase with checked-in time.
  Future<void> _checkInCustomer() async {

    if (!(UniversalPlatform.isIOS || UniversalPlatform.isAndroid)) {
      _showSnackBar(message: "Check-In only available on Mobile Devices.");
      return;
    }

    _progressModel.setData(
        status: KeanuStatus.loading,
        message: "Looking for network scanners...");

    // Find Scanners in the network.
    List<Connector> foundScanners = await _fetchWifiScanners();
    // If no scanner found return and show toast.
    if (foundScanners.isEmpty) {
      _progressModel.setData(status: KeanuStatus.none);
      _showSnackBar(message: "No scanners found. Try again");
      return;
    }

    _progressModel.setData(
        status: KeanuStatus.loading, message: "Scanning Driver License...");

    // Scan image.
    List<String> scannedPaths = await _scanFiles(foundScanners.single);

    if (scannedPaths.isEmpty) {
      _progressModel.setData(status: KeanuStatus.none);
      _showSnackBar(message: "Place Driver License in Scanner. Try again");
      return;
    }
    final scannedFilePath = scannedPaths.single;

    _progressModel.setData(
        status: KeanuStatus.loading,
        message: "Reading customer information...");

    // Send it through the text recognizer.
    final inputImage = InputImage.fromFilePath(scannedFilePath);

    /*
    final List<BarcodeFormat> formats = [BarcodeFormat.pdf417];
    final barcodeScanner = BarcodeScanner(formats: formats);
    final List<Barcode> barcodes = await barcodeScanner.processImage(inputImage);
    print("Code Data: ${barcodes.single.rawValue}");
    barcodeScanner.close();
    */
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);
    String text = recognizedText.text;
    print("Recognized Tex: $text");
    for (TextBlock block in recognizedText.blocks) {
      final String text = block.text;
      print("Block Text: $text");
    }
    textRecognizer.close();

    if (recognizedText.blocks.length < 3 || getNumber(line: text) == null) {
      _progressModel.setData(status: KeanuStatus.none);
      _showSnackBar(message: "Unable to process Driver License. Try again");
      return;
    }

    // Extract license number
    String licenseNumber = getNumber(line: text)!; //parts[2];
    // Extract first name
    String firstName = recognizedText.blocks[2].text; //parts[3];
    // Extract last name
    String lastName = recognizedText.blocks[3].text; //parts[4];
    // Use scan time as check in time.
    String checkInTime = Day().toUtc().toIso8601String();

    // Add record to Quickbase
    Customer customer = Customer(
        checkedInTime: checkInTime,
        firstName: firstName,
        lastName: lastName,
        licenseNumber: licenseNumber,
        ratePerHour: kDefaultRatePerHour,
        //imageUrl: scannedFilePath,
        isCheckedOut: false);

    /*
    Customer customer = Customer(
        checkedInTime: Day().toUtc().toIso8601String(),
        firstName: "Frank",
        lastName: "H",
        licenseNumber: "licenseNumber",
        isCheckedOut: false);

     */

    _progressModel.setData(status: KeanuStatus.none);

    // Show Customer checking dialog.
    Customer? editedCustomer =
        await _showCustomerCheckInDialog(customerToEdit: customer);

    if (editedCustomer == null) {
      return;
    }

    print("Inserting Customer: $editedCustomer");
    await _insertCustomer(customer: editedCustomer, client: client);

    // Update list.
    setState(() {
      _pagingController.itemList?.add(editedCustomer);
    });
  }

  ///
  /// Performs the checkout of a client.
  /// Based on the check-in and check-out times it will
  /// calculate the total cost of the lessons.
  ///
  Future<void> _performCustomerCheckout() async {
    /*
    Customer customerToCheckout2 = Customer(
        checkedInTime: Day().toUtc().toIso8601String(),
        checkedOutTime: Day().toUtc().toIso8601String(), // Day().add(3, "h")!.toUtc().toIso8601String(),
        firstName: "Frank",
        lastName: "H",
        licenseNumber: "licenseNumber",
        ratePerHour: kDefaultRatePerHour,
        isCheckedOut: false);

    print("Total Charge: ${customerToCheckout2.totalCharge}");

     */

    //print ("FOund number : ${getNumber(line: "Florido SiTishine Slate DRIVER LICENSE CLASSE H655-245-85-002-0 FRANCISCO ERNESTO")}");

    if (!(UniversalPlatform.isIOS || UniversalPlatform.isAndroid)) {
      _showSnackBar(message: "Check-Out only available on Mobile Devices.");
      return;
    }

    _progressModel.setData(
        status: KeanuStatus.loading,
        message: "Looking for network scanners...");
    // Scan license
    // Find Scanners in the network.
    List<Connector> foundScanners = await _fetchWifiScanners();
    // If no scanner found return and show toast.
    if (foundScanners.isEmpty) {
      _progressModel.setData(status: KeanuStatus.none);
      _showSnackBar(message: "No scanners found. Try again");
      return;
    }

    _progressModel.setData(
        status: KeanuStatus.loading, message: "Scanning Driver's License...");

    // Scan image.
    List<String> scannedPaths = await _scanFiles(foundScanners.single);

    if (scannedPaths.isEmpty) {
      _progressModel.setData(status: KeanuStatus.none);
      _showSnackBar(message: "Place Driver's License in Scanner. Try again");
      return;
    }
    final scannedFilePath = scannedPaths.single;

    _progressModel.setData(
        status: KeanuStatus.loading,
        message: "Reading customer information...");

    // Send it through the text recognizer.
    final inputImage = InputImage.fromFilePath(scannedFilePath);

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);
    String text = recognizedText.text;
    print("Recognized Tex: $text");
    for (TextBlock block in recognizedText.blocks) {
      final String text = block.text;
      print("Block Text: $text");
    }
    textRecognizer.close();

    if (recognizedText.blocks.length < 3) {
      _progressModel.setData(status: KeanuStatus.none);
      _showSnackBar(message: "Unable to process Driver's License. Try again");
      return;
    }

    // Extract license number
    String licenseNumber = getNumber(line: text)!;
    // Use scan time as check in time.
    String checkOutTime = Day().toUtc().toIso8601String();

    _progressModel.setData(
        status: KeanuStatus.loading, message: "Finding customer...");

    // Find customer in Quickbase for customer
    Customer? customerToCheckout = await _fetchCheckedInCustomer(
        licenseNumber: licenseNumber, client: client);

    if (customerToCheckout == null) {
      _progressModel.setData(status: KeanuStatus.none);
      _showSnackBar(
          message:
              "No checked-in customer found with this license number. Try again");
      return;
    }

    customerToCheckout.checkedOutTime = checkOutTime;

    /* Test customer.
    Customer customerToCheckout = Customer(
        checkedInTime: Day().toUtc().toIso8601String(),
        checkedOutTime: Day().add(3, "h")!.toUtc().toIso8601String(),
        firstName: "Frank",
        lastName: "H",
        licenseNumber: "licenseNumber",
        ratePerHour: kDefaultRatePerHour,
        isCheckedOut: false);

     */

    _progressModel.setData(status: KeanuStatus.none);

    // Display confirmation dialog with total cost
    Customer? editedCustomer =
        await _showCustomerCheckOutDialog(customerToEdit: customerToCheckout);
    if (editedCustomer == null) {
      return;
    }

    print("Updating Customer: $customerToCheckout");
    await _updateCustomer(customer: customerToCheckout, client: client);

    // Update list.
    setState(() {
      _pagingController.itemList?.removeWhere((element) =>
          element.licenseNumber == customerToCheckout.licenseNumber);
    });
  }

  ///
  /// Shows a form to check-in the customer.
  ///
  Future<Customer?> _showCustomerCheckInDialog(
      {required Customer customerToEdit}) async {
    _activeCustomer = customerToEdit.copyWidth();
    Customer? customer = await _showBaseCustomerDialog(isCheckOut: false);
    if (customer != null) {
      print("Form Customer $customer");
      customerToEdit.ratePerHour = customer.ratePerHour;
      return customerToEdit;
    }
    return null;
  }

  ///
  /// Shows a form to check-out the customer.
  ///
  Future<Customer?> _showCustomerCheckOutDialog(
      {required Customer customerToEdit}) async {
    _activeCustomer = customerToEdit.copyWidth();
    Customer? customer = await _showBaseCustomerDialog(isCheckOut: true);
    if (customer != null) {
      customerToEdit.isCheckedOut = true;
      customerToEdit.firstName = customer.firstName;
      customerToEdit.lastName = customer.lastName;
      customerToEdit.ratePerHour = customer.ratePerHour;
      customerToEdit.checkedOutTime = customerToEdit.checkedOutTime;
      customerToEdit.total = customerToEdit.totalCharge;
      return customerToEdit;
    }
    return null;
  }

  Future<Customer?> _showBaseCustomerDialog({bool isCheckOut = false}) {
    return showGeneralDialog<Customer?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Barrier",
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Container();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeInOutBack.transform(anim1.value) - 1.0;
        return Transform(
            transform: Matrix4.translationValues(0.0, curvedValue * 200, 0.0),
            child: Opacity(
              opacity: anim1.value,
              child: _buildBaseDialogBody(
                  child: _createCustomerCheckInForm(
                      context: context,
                      setState: setState,
                      isCheckOut: isCheckOut)),
            ));
      },
    );
  }

  Widget _buildBaseDialogBody({required Widget child}) {
    return Dialog(
        backgroundColor: Colors.transparent,
        child: StatefulBuilder(builder: (context, StateSetter setState) {
          ThemeData theme = Theme.of(context);
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: theme.colorScheme.background,
                      borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, bottom: 16.0, top: 60),
                    child: SizedBox(
                        width: 400, child: SingleChildScrollView(child: child)),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                child: Center(
                  child: buildAppLogo(width: 100, height: 100),
                ),
              ),
            ],
          );
        }));
  }

  Future<bool?> _showBaseConfirmationDialogDialog(
      {required Widget body, required String positive}) {
    return showGeneralDialog<bool?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Barrier",
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Container();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeInOutBack.transform(anim1.value) - 1.0;
        return Transform(
          transform: Matrix4.translationValues(0.0, curvedValue * 200, 0.0),
          child: Opacity(
            opacity: anim1.value,
            child: _buildBaseDialogBody(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  body,
                  const SizedBox(
                    height: 16,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48), // NEW
                          ),
                          onPressed: () {
                            // Validate returns true if the form is valid, or false otherwise.
                            Navigator.pop(context, true);
                          },
                          child: Text(positive),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _createCustomerCheckInForm(
      {required BuildContext context,
      bool isCheckOut = false,
      required StateSetter setState}) {
    return Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_activeCustomer!.imageUrl != null && _activeCustomer!.imageUrl?.isNotEmpty == true) ...[
              InteractiveViewer(
                  child: Image.file(File(_activeCustomer!.imageUrl!)))
            ],
            RichText(
              text: TextSpan(
                text: 'Name: ',
                style: kLabelTextStyle.copyWith(
                    fontWeight: FontWeight.bold, fontSize: 20),
                children: <TextSpan>[
                  TextSpan(
                      text: '${_activeCustomer?.nameLine}',
                      style: kLabelTextStyle.copyWith(
                          fontWeight: FontWeight.normal))
                ],
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            RichText(
              text: TextSpan(
                text: 'Check-In: ',
                style: kLabelTextStyle.copyWith(
                    fontWeight: FontWeight.bold, fontSize: 18),
                children: <TextSpan>[
                  TextSpan(
                      text: '${_activeCustomer?.localCheckIn}',
                      style: kLabelTextStyle.copyWith(
                          fontWeight: FontWeight.normal))
                ],
              ),
            ),
            const SizedBox(
              height: 8,
            ),

            if (isCheckOut) ...[
              RichText(
                text: TextSpan(
                  text: 'Check-Out: ',
                  style: kLabelTextStyle.copyWith(
                      fontWeight: FontWeight.bold, fontSize: 18),
                  children: <TextSpan>[
                    TextSpan(
                        text: '${_activeCustomer?.localCheckOut}',
                        style: kLabelTextStyle.copyWith(
                            fontWeight: FontWeight.normal))
                  ],
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              RichText(
                text: TextSpan(
                  text: 'Total: ',
                  style: kLabelTextStyle.copyWith(
                      fontWeight: FontWeight.bold, fontSize: 18),
                  children: <TextSpan>[
                    TextSpan(
                        text: '\$${_activeCustomer?.totalCharge}',
                        style: kLabelTextStyle.copyWith(
                            fontWeight: FontWeight.normal))
                  ],
                ),
              ),
              const SizedBox(
                height: 8,
              ),
            ] else ...[
              TextFormField(
                initialValue:
                    "${_activeCustomer?.ratePerHour ?? kDefaultRatePerHour}",
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "\$/hour:"),
                // The validator receives the text that the user has entered.
                validator: (value) {
                  double rate =
                      parseRate(rateStr: value?.replaceAll("\$", " "));
                  if (rate < 0) {
                    return 'Please enter a valid rate';
                  }
                  _activeCustomer?.ratePerHour = rate;
                  return null;
                },
              )
            ],
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48), // NEW
                ),
                onPressed: () {
                  print("Validating input");
                  // Validate returns true if the form is valid, or false otherwise.
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, _activeCustomer);
                  }
                },
                child: isCheckOut
                    ? const Text('Check-Out')
                    : const Text("Check-In"),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ));
  }

  double parseRate({String? rateStr}) {
    print("Parsing $rateStr");
    if (rateStr == null) {
      return -1.0;
    }

    try {
      return double.parse(rateStr);
    } catch (e) {
      return -1.0;
    }
  }
}

class ProgressOverlay extends StatelessWidget {
  const ProgressOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ProgressModel progressModel = context.read();

    if (progressModel.status == KeanuStatus.loading) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Center(
                child: SizedBox(
                    width: 200,
                    child: kDefaultComposition == null ? Lottie.asset(
                        'assets/lottie/van_morphing_animation.json'): Lottie(composition: kDefaultComposition!))),
            if (progressModel.message != null) ...[
              AnimatedSwitcher(key: ValueKey<String>(progressModel.message!),
                duration: const Duration(microseconds: 600),
                child: Text(
                  progressModel.message!,
                  style: kLabelTextStyle.copyWith(fontSize: 20),
                ),
              ),
            ]
          ],
        ),
      );
    }

    return Container();
  }
}

class CustomerCheckedInCardView extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleteTap;

  const CustomerCheckedInCardView(
      {Key? key,
      required this.customer,
      this.onTap,
      this.onLongPress,
      this.onDeleteTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: onLongPress,
      onTap: onTap,
      child: TweenAnimationBuilder<Color?>(
        duration: const Duration(milliseconds: 1000),
        tween: ColorTween(
            begin: Colors.white,
            end: customer.isSelected ? Colors.lightBlueAccent : Colors.white),
        builder: (context, color, child) {
          return ColorFiltered(
            child: child,
            colorFilter: ColorFilter.mode(color!, BlendMode.modulate),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Card(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        customer.nameLine,
                        style: kLabelTextStyle.copyWith(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "CheckIn: ${Day.fromDateTime(DateTime.parse(customer.checkedInTime!).toLocal()).format("hh:mm A")}",
                        style: kLabelTextStyle.copyWith(fontSize: 14),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (customer.isSelected) ...[
              Positioned(
                  right: 0,
                  child: GestureDetector(
                    onTap: onDeleteTap,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSecondary,),
                    ),
                  ))
            ]
          ],
        ),
      ),
    );
  }
}

mixin HowzieLogo {
  Widget buildAppLogo({required double width, required double height}) {
    return Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
              image: AssetImage("assets/images/surfer_retro_small.png"),
              fit: BoxFit.fill),
        ));
  }
}

mixin BrotherScanner {
  ///
  /// Looks for scanners on the local network.
  ///
  Future<List<Connector>> _fetchWifiScanners({int timeout = 2000}) =>
      AirBrother.getNetworkDevices(timeout);

  ///
  /// Looks for usb scanners.
  //Future<List<Connector>> _fetchUsbScanners({int timeout = 3000}) => AirBrother.getUsbDevices(timeout);

  ///
  /// Scans the files using the Brother Scanner
  ///
  Future<List<String>> _scanFiles(Connector connector) async {
    List<String> outScannedPaths = [];
    ScanParameters scanParams = ScanParameters();
    scanParams.documentSize = MediaSize.C5Envelope;
    JobState jobState =
        await connector.performScan(scanParams, outScannedPaths);
    print("JobState: $jobState");
    print("Files Scanned: $outScannedPaths");
    return outScannedPaths;
  }
}

mixin CustomerQuickbase {
  ///
  /// Deletes the specified customer.
  /// Returns number of deleted records on success.
  ///
  Future<int> _deleteCustomer(
      {required Customer customer, required QuickBaseClient client}) async {
    var queryBuffer = StringBuffer();
    queryBuffer.write("{'3'.EX.'${customer.recordId}'}");
    String where = queryBuffer.toString();

    int deletedCount = await client.deleteRecords(
        request: RecordsDeleteRequest(
            from: AppKeys.quickbaseContactTableId, where: where));

    return deletedCount;
  }

  ///
  /// Adds a new customer record.
  ///
  Future<Customer> _insertCustomer(
      {required Customer customer, required QuickBaseClient client}) async {
    var data = [
      {
        "6": {"value": customer.licenseNumber},
        "7": {"value": customer.lastName},
        "8": {"value": customer.firstName},
        "9": {"value": customer.imageUrl},
        "10": {"value": customer.checkedInTime},
        "11": {"value": customer.checkedOutTime},
        "12": {"value": customer.total},
        "13": {"value": customer.isCheckedOut},
        "14": {"value": customer.ratePerHour}
      }
    ];

    RecordsUpsertResponse response = await client.upsert(
        request: RecordsUpsertRequest(
            to: AppKeys.quickbaseContactTableId,
            data: data,
            fieldsToReturn: [3, 6, 7, 8, 9, 10, 11, 12, 13]));

    customer.recordId = response.data![0]["3"]["value"];
    return customer;
  }

  ///
  /// Updates an existing customer record.
  ///
  Future<void> _updateCustomer(
      {required Customer customer, required QuickBaseClient client}) async {
    var data = [
      {
        "3": {"value": "${customer.recordId}"},
        "6": {"value": customer.licenseNumber},
        "7": {"value": customer.lastName},
        "8": {"value": customer.firstName},
        "9": {"value": customer.imageUrl},
        "10": {"value": customer.checkedInTime},
        "11": {"value": customer.checkedOutTime},
        "12": {"value": customer.total},
        "13": {"value": customer.isCheckedOut},
        "14": {"value": customer.ratePerHour}
      }
    ];

    RecordsUpsertResponse response = await client.upsert(
        request: RecordsUpsertRequest(
            to: AppKeys.quickbaseContactTableId,
            data: data,
            fieldsToReturn: [3, 6, 7, 8, 9, 10, 11, 12, 13, 14]));
  }

  ///
  /// Fetches a page of checked out customers.
  ///
  Future<List<Customer>> _fetchCheckedOut(
      {required int page,
      required int pageSize,
      required QuickBaseClient client}) async {
    await client.initialize();

    var contactTable = await client.getTable(
        tableId: AppKeys.quickbaseContactTableId,
        appId: AppKeys.quickbaseAppId);

    var queryBuffer = StringBuffer();
    queryBuffer.write("{'13'.EX.'1'}");
    String where = queryBuffer.toString();

    RecordsQueryResponse contacts = await client.runQuery(
        request: RecordsQueryRequest(
            where: where,
            select: [3, 6, 7, 8, 9, 10, 11, 12, 13, 14],
            from: contactTable.id!,
            options: RecordsQueryOptions(skip: page, top: pageSize)));

    List<Customer> customers = contacts.data?.map((item) {
          return item.toCustomer();
        }).toList() ??
        List<Customer>.empty();
    return customers;
  }

  ///
  /// Fetches a page of checked in customers.
  ///
  Future<List<Customer>> _fetchCheckedIn(
      {required int page,
      required int pageSize,
      required QuickBaseClient client}) async {
    await client.initialize();

    var contactTable = await client.getTable(
        tableId: AppKeys.quickbaseContactTableId,
        appId: AppKeys.quickbaseAppId);

    var queryBuffer = StringBuffer();
    //queryBuffer.write("{'3'.EX.'${customer.recordId}'}");
    queryBuffer.write("{'13'.EX.'0'}");
    String where = queryBuffer.toString();

    RecordsQueryResponse contacts = await client.runQuery(
        request: RecordsQueryRequest(
            where: where,
            select: [3, 6, 7, 8, 9, 10, 11, 12, 13, 14],
            from: contactTable.id!,
            options: RecordsQueryOptions(skip: page, top: pageSize)));

    List<Customer> customers = contacts.data?.map((item) {
          return item.toCustomer();
        }).toList() ??
        List<Customer>.empty();

    return customers;
  }

  Future<Customer?> _fetchCheckedInCustomer(
      {required String licenseNumber, required QuickBaseClient client}) async {
    await client.initialize();

    var contactTable = await client.getTable(
        tableId: AppKeys.quickbaseContactTableId,
        appId: AppKeys.quickbaseAppId);

    print("Searching for license: ${licenseNumber}");
    var queryBuffer = StringBuffer();
    queryBuffer.write("{'6'.EX.'$licenseNumber'}");
    queryBuffer.write("AND");
    queryBuffer.write("{'13'.XEX.'1'}");
    String where = queryBuffer.toString();

    RecordsQueryResponse contacts = await client.runQuery(
        request: RecordsQueryRequest(
            where: where,
            select: [3, 6, 7, 8, 9, 10, 11, 12, 13, 14],
            from: contactTable.id!));

    List<Customer> customers = contacts.data?.map((item) {
          return item.toCustomer();
        }).toList() ??
        List<Customer>.empty();

    if (customers.isEmpty) {
      return null;
    }

    return customers.single;
  }
}

mixin UsLicenseNumber {
  final _licenseNumberRegEx = RegExp(
      r'^.*([A-Z0-9]{4}-[A-Z0-9]{3}-[A-Z0-9]{2}-[A-Z0-9]{3}-[A-Z0-9]).*$');

  String? getNumber({required String line}) {
    line = line.replaceAll("\n", " ");
    print(
        "Trying to match: $line --- ${_licenseNumberRegEx.stringMatch(line)}");

    if (_licenseNumberRegEx.hasMatch(line)) {
      print("HasMatch: ${_licenseNumberRegEx.firstMatch(line)}");
      return _licenseNumberRegEx.firstMatch(line)?.group(1);
    }
    return null;
  }
}

@immutable
class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    Key? key,
    this.initialOpen,
    this.mainFabBody,
    required this.distance,
    required this.children,
  }) : super(key: key);

  final bool? initialOpen;
  final double distance;
  final List<Widget> children;
  final Widget? mainFabBody;

  @override
  _ExpandableFabState createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _open = widget.initialOpen ?? false;
    _controller = AnimationController(
      value: _open ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          _buildTapToCloseFab(),
          ..._buildExpandingActionButtons(),
          _buildTapToOpenFab(),
        ],
      ),
    );
  }

  Widget _buildTapToCloseFab() {
    return SizedBox(
      width: 56.0,
      height: 56.0,
      child: Center(
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 4.0,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.children.length;
    final step = 90.0 / (count - 1);
    for (var i = 0, angleInDegrees = 0.0;
        i < count;
        i++, angleInDegrees += step) {
      children.add(
        _ExpandingActionButton(
          directionInDegrees: angleInDegrees,
          maxDistance: widget.distance,
          progress: _expandAnimation,
          child: widget.children[i],
        ),
      );
    }
    return children;
  }

  Widget _buildTapToOpenFab() {
    return IgnorePointer(
      ignoring: _open,
      child: AnimatedContainer(
        transformAlignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          _open ? 0.7 : 1.0,
          _open ? 0.7 : 1.0,
          1.0,
        ),
        duration: const Duration(milliseconds: 250),
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        child: AnimatedOpacity(
          opacity: _open ? 0.0 : 1.0,
          curve: const Interval(0.25, 1.0, curve: Curves.easeInOut),
          duration: const Duration(milliseconds: 250),
          child: FloatingActionButton(
            onPressed: _toggle,
            child: widget.mainFabBody,
          ),
        ),
      ),
    );
  }
}

@immutable
class _ExpandingActionButton extends StatelessWidget {
  const _ExpandingActionButton({
    Key? key,
    required this.directionInDegrees,
    required this.maxDistance,
    required this.progress,
    required this.child,
  }) : super(key: key);

  final double directionInDegrees;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final offset = Offset.fromDirection(
          directionInDegrees * (math.pi / 180.0),
          progress.value * maxDistance,
        );
        return Positioned(
          right: 4.0 + offset.dx,
          bottom: 4.0 + offset.dy,
          child: Transform.rotate(
            angle: (1.0 - progress.value) * math.pi / 2,
            child: child!,
          ),
        );
      },
      child: FadeTransition(
        opacity: progress,
        child: child,
      ),
    );
  }
}

@immutable
class ActionButton extends StatelessWidget {
  const ActionButton({
    Key? key,
    this.onPressed,
    required this.icon,
  }) : super(key: key);

  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.secondary,
      elevation: 4.0,
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        color: theme.colorScheme.onPrimary,
      ),
    );
  }
}

class HowzieAppBar extends StatelessWidget
    with PreferredSizeWidget, HowzieLogo {
  final String title;

  const HowzieAppBar({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppBar(
          centerTitle: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(180)),
          title:
              Text(title, style: GoogleFonts.loveYaLikeASister(fontSize: 30)),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Center(
            child: buildAppLogo(width: kToolbarHeight, height: kToolbarHeight),
          ),
        ),

        Positioned(
          left: 0,
          child: AnalogClock(
            height:kToolbarHeight,
            decoration: BoxDecoration(
                border: Border.all(width: 1.0, color: Colors.black),
                color: Colors.transparent,
                shape: BoxShape.circle),
            width: kToolbarHeight,
            isLive: true,
            hourHandColor: Colors.black,
            minuteHandColor: Colors.black,
            showSecondHand: true,
            numberColor: Colors.black87,
            showNumbers: true,
            textScaleFactor: 1.4,
            showTicks: false,
            datetime: DateTime.now(),
          ),
        )


      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

enum KeanuStatus { none, loading, done, error }

class ProgressModel extends EasyNotifier {
  ProgressModel({required KeanuStatus status, String? message}) {
    _status = status;
    _message = message;
  }

  KeanuStatus _status = KeanuStatus.none;

  KeanuStatus get status => _status;

  String? _message;

  String? get message => _message;

  void setData({required KeanuStatus status, String? message}) {
    notify(() {
      _message = message;
      _status = status;
    });
  }
}

class Customer {
  int? recordId;
  String? firstName;
  String? lastName;
  String? checkedInTime;
  String? checkedOutTime;
  double? total;
  String? imageUrl;
  String? licenseNumber;
  bool isSelected;
  double? ratePerHour;
  bool? isCheckedOut;

  Customer(
      {this.recordId,
      this.checkedInTime,
      this.checkedOutTime,
      this.firstName,
      this.lastName,
      this.imageUrl,
      this.total,
      this.licenseNumber,
      this.isCheckedOut,
      this.ratePerHour,
      this.isSelected = false});

  String get nameLine => "$lastName, ${firstName![0]}";

  String get localCheckIn => checkedInTime == null
      ? ""
      : Day.fromDateTime(DateTime.parse(checkedInTime!).toLocal())
          .format("hh:mm A");

  String get localCheckOut => checkedOutTime == null
      ? ""
      : Day.fromDateTime(DateTime.parse(checkedOutTime!).toLocal())
          .format("hh:mm A");

  double get totalCharge {
    if (checkedOutTime?.isNotEmpty == true &&
        checkedInTime?.isNotEmpty == true &&
        ratePerHour != null) {
      Duration diff = DateTime.parse(checkedOutTime!)
          .difference(DateTime.parse(checkedInTime!));
      int minutes = diff.inMinutes;
      // Charge even if no time has passed since check in for demo.
      if (minutes == 0) {
        minutes = 1;
      }
      return (minutes / 60.0).ceil() * ratePerHour!;
    }
    return 0;
  }

  Customer copyWidth(
      {int? recordId,
      String? firstName,
      String? lastName,
      String? checkedItTime,
      String? checkedOutTime,
      String? imageUrl,
      double? total,
      String? licenseNumber,
      bool? isCheckedOut,
      double? ratePerHour,
      bool? isSelected}) {
    return Customer(
        recordId: recordId ?? this.recordId,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        checkedInTime: checkedItTime ?? this.checkedInTime,
        checkedOutTime: checkedOutTime ?? this.checkedOutTime,
        imageUrl: imageUrl ?? this.imageUrl,
        total: total ?? this.total,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        isCheckedOut: isCheckedOut ?? this.isCheckedOut,
        ratePerHour: ratePerHour ?? this.ratePerHour,
        isSelected: isSelected ?? this.isSelected);
  }

  @override
  String toString() {
    return "Id: $recordId, Fname: $firstName, LName: $lastName, CheckIn: $checkedInTime, CheckOut: $checkedOutTime, RatePerHour: $ratePerHour}";
  }
}

extension QuickbaseConverter on Map<String, dynamic> {
  Customer toCustomer() {
    print("Record: ${this}");
    return Customer(
        recordId: this["3"]["value"],
        licenseNumber: "${this["6"]["value"]}",
        lastName: "${this["7"]["value"]}",
        firstName: "${this["8"]["value"]}",
        imageUrl: "${this["9"]["value"]}",
        checkedInTime: "${this["10"]["value"]}",
        checkedOutTime: "${this["11"]["value"]}",
        total: this["12"]["value"],
        isCheckedOut: this["13"]["value"],
        ratePerHour: this["14"]["value"]);
  }
}
