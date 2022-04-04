codeunit 70104 "PTE Test Library"
{
    procedure CreateItemWithUnitPriceAndUnitCost(var Item: Record Item; UnitPrice: Decimal; UnitCost: Decimal)
    begin
        CreateItem(Item);
        Item.Validate("Costing Method", Item."Costing Method"::Average);
        Item.Validate("Unit Price", UnitPrice);
        Item.Validate("Unit Cost", UnitCost);
        Item.Modify(true);
    end;

    procedure CreatePurchaseDocumentWithItem(var PurchaseHeader: Record "Purchase Header"; VendorNo: Code[20]; ItemNo: Code[20]; Amount: Decimal; LocationCode: Code[10]; ExpectedReceiptDate: Date)
    var
        PurchaseLine: Record "Purchase Line";
    begin
        CreateFCYPurchaseDocumentWithItem(
          PurchaseHeader, PurchaseLine, "Purchase Document Type"::Order, VendorNo, ItemNo, Amount, LocationCode, ExpectedReceiptDate, '');
    end;

    procedure PostPurchaseDocument(var PurchaseHeader: Record "Purchase Header"; ToShipReceive: Boolean; ToInvoice: Boolean) DocumentNo: Code[20]
    var
        NoSeriesManagement: Codeunit NoSeriesManagement;
        NoSeriesCode: Code[20];
    begin
        // Post the purchase document.
        // Depending on the document type and posting type return the number of the:
        // - purchase receipt,
        // - posted purchase invoice,
        // - purchase return shipment, or
        // - posted credit memo
        // SetCorrDocNoPurchase(PurchaseHeader);
        with PurchaseHeader do begin
            Validate(Receive, ToShipReceive);
            Validate(Ship, ToShipReceive);
            Validate(Invoice, ToInvoice);

            case "Document Type" of
                "Document Type"::Invoice:
                    NoSeriesCode := "Posting No. Series"; // posted purchase invoice
                "Document Type"::Order:
                    if ToShipReceive and not ToInvoice then
                        NoSeriesCode := "Receiving No. Series" // posted purchase receipt
                    else
                        NoSeriesCode := "Posting No. Series"; // posted purchase invoice
                "Document Type"::"Credit Memo":
                    NoSeriesCode := "Posting No. Series"; // posted purchase credit memo
                "Document Type"::"Return Order":
                    if ToShipReceive and not ToInvoice then
                        NoSeriesCode := "Return Shipment No. Series" // posted purchase return shipment
                    else
                        NoSeriesCode := "Posting No. Series"; // posted purchase credit memo
                else
            // Assert.Fail(StrSubstNo('Document type not supported: %1', "Document Type"))
            end
        end;

        if NoSeriesCode = '' then
            DocumentNo := PurchaseHeader."No.";
        CODEUNIT.Run(CODEUNIT::"Purch.-Post", PurchaseHeader);
    end;


    local procedure CreateFCYPurchaseDocumentWithItem(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; DocumentType: Enum "Purchase Document Type"; VendorNo: Code[20]; ItemNo: Code[20]; Amount: Decimal; LocationCode: Code[10]; ExpectedReceiptDate: Date; CurrencyCode: Code[10])
    begin
        CreatePurchHeader(PurchaseHeader, DocumentType, VendorNo);
        if LocationCode <> '' then
            PurchaseHeader.Validate("Location Code", LocationCode);
        PurchaseHeader.Validate("Currency Code", CurrencyCode);
        PurchaseHeader.Modify(true);
        CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, ItemNo, Amount);
        if LocationCode <> '' then
            PurchaseLine.Validate("Location Code", LocationCode);
        if ExpectedReceiptDate <> 0D then
            PurchaseLine.Validate("Expected Receipt Date", ExpectedReceiptDate);
        PurchaseLine.Modify(true);
    end;

    local procedure CreatePurchHeader(var PurchaseHeader: Record "Purchase Header"; DocumentType: Enum "Purchase Document Type"; BuyfromVendorNo: Code[20])
    begin
        // DisableWarningOnCloseUnpostedDoc;
        // DisableWarningOnCloseUnreleasedDoc;
        // DisableConfirmOnPostingDoc;
        Clear(PurchaseHeader);
        PurchaseHeader.Validate("Document Type", DocumentType);
        PurchaseHeader.Insert(true);
        // if BuyfromVendorNo = '' then
        //     BuyfromVendorNo := CreateVendorNo;
        PurchaseHeader.Validate("Buy-from Vendor No.", BuyfromVendorNo);
        PurchaseHeader.Validate("Vendor Invoice No.", GenerateGUID);
        // SetCorrDocNoPurchase(PurchaseHeader);
        PurchaseHeader.Modify(true);
    end;

    local procedure CreatePurchaseLine(var PurchaseLine: Record "Purchase Line"; PurchaseHeader: Record "Purchase Header"; LineType: Enum "Purchase Line Type"; No: Code[20]; Amount: Decimal)
    begin
        CreatePurchaseLineSimple(PurchaseLine, PurchaseHeader);

        PurchaseLine.Validate(Type, LineType);
        PurchaseLine.Validate("No.", No);
        if LineType <> PurchaseLine.Type::" " then
            PurchaseLine.Validate(Quantity, 1);
        if Amount <> 0 then
            PurchaseLine.Validate(Amount, Amount);
        PurchaseLine.Modify(true);

    end;

    local procedure CreatePurchaseLineSimple(var PurchaseLine: Record "Purchase Line"; PurchaseHeader: Record "Purchase Header")
    var
        RecRef: RecordRef;
    begin
        PurchaseLine.Init();
        PurchaseLine.Validate("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.Validate("Document No.", PurchaseHeader."No.");
        RecRef.GetTable(PurchaseLine);
        PurchaseLine.Validate("Line No.", 10000);
        PurchaseLine.Insert(true);
    end;


    local procedure CreateItem(var Item: Record Item): Code[20]
    var
        VATPostingSetup: Record "VAT Posting Setup";
    begin
        CreateItemWithoutVAT(Item);

        FindVATPostingSetupInvt(VATPostingSetup);
        Item.Validate("VAT Prod. Posting Group", VATPostingSetup."VAT Prod. Posting Group");

        Item.Modify(true);
        // OnAfterCreateItem(Item);
        exit(Item."No.");
    end;

    local procedure CreateItemWithoutVAT(var Item: Record Item)
    var
        InventorySetup: Record "Inventory Setup";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        GeneralPostingSetup: Record "General Posting Setup";
        InventoryPostingGroup: Record "Inventory Posting Group";
        TaxGroup: Record "Tax Group";
    begin
        ItemNoSeriesSetup(InventorySetup);
        Clear(Item);
        Item.Insert(true);

        CreateItemUnitOfMeasure(ItemUnitOfMeasure, Item."No.", '', 1);
        FindGeneralPostingSetupInvtFull(GeneralPostingSetup);

        if not InventoryPostingGroup.FindFirst then
            CreateInventoryPostingGroup(InventoryPostingGroup);

        Item.Validate(Description, Item."No.");  // Validation Description as No. because value is not important.
        Item.Validate("Base Unit of Measure", ItemUnitOfMeasure.Code);
        Item.Validate("Gen. Prod. Posting Group", GeneralPostingSetup."Gen. Prod. Posting Group");
        Item.Validate("Inventory Posting Group", InventoryPostingGroup.Code);

        if TaxGroup.FindFirst then
            Item.Validate("Tax Group Code", TaxGroup.Code);

        Item.Modify(true);
    end;

    local procedure CreateItemUnitOfMeasure(var ItemUnitOfMeasure: Record "Item Unit of Measure"; ItemNo: Code[20]; UnitOfMeasureCode: Code[10]; QtyPerUoM: Decimal)
    begin
        CreateItemUnitOfMeasure(ItemUnitOfMeasure, ItemNo, UnitOfMeasureCode, QtyPerUoM, 0);
    end;

    local procedure FindVATPostingSetupInvt(var VATPostingSetup: Record "VAT Posting Setup")
    var
        SearchPostingType: Option All,Sales,Purchase;
    begin
        VATPostingSetup.SetFilter("VAT Prod. Posting Group", '<>%1', '');
        VATPostingSetup.SetFilter("VAT %", '<>%1', 0);
        VATPostingSetup.SetRange("VAT Calculation Type", VATPostingSetup."VAT Calculation Type"::"Normal VAT");
        if SearchPostingType <> SearchPostingType::Purchase then
            VATPostingSetup.SetFilter("Sales VAT Account", '<>%1', '');
        if SearchPostingType <> SearchPostingType::Sales then
            VATPostingSetup.SetFilter("Purchase VAT Account", '<>%1', '');
        if not VATPostingSetup.FindFirst then
            CreateVATPostingSetupWithAccounts(VATPostingSetup,
              VATPostingSetup."VAT Calculation Type"::"Normal VAT", 10);
    end;


    local procedure CreateItemUnitOfMeasure(var ItemUnitOfMeasure: Record "Item Unit of Measure"; ItemNo: Code[20]; UnitOfMeasureCode: Code[10]; QtyPerUoM: Decimal; QtyRndPrecision: Decimal)
    var
        UnitOfMeasure: Record "Unit of Measure";
    begin
        ItemUnitOfMeasure.Init();
        ItemUnitOfMeasure.Validate("Item No.", ItemNo);

        // The IF condition is important because it grants flexibility to the function.
        if UnitOfMeasureCode = '' then begin
            UnitOfMeasure.SetFilter(Code, '<>%1', UnitOfMeasureCode);
            UnitOfMeasure.FindFirst;
            ItemUnitOfMeasure.Validate(Code, UnitOfMeasure.Code);
        end else
            ItemUnitOfMeasure.Validate(Code, UnitOfMeasureCode);
        if QtyPerUoM = 0 then
            QtyPerUoM := 1;
        ItemUnitOfMeasure.Validate("Qty. per Unit of Measure", QtyPerUoM);

        if QtyRndPrecision <> 0 then
            ItemUnitOfMeasure.Validate("Qty. Rounding Precision", QtyRndPrecision);
        ItemUnitOfMeasure.Insert(true);
    end;


    local procedure ItemNoSeriesSetup(var InventorySetup: Record "Inventory Setup")
    var
        NoSeriesCode: Code[20];
    begin
        InventorySetup.Get();
        NoSeriesCode := GetGlobalNoSeriesCode;
        if NoSeriesCode <> InventorySetup."Item Nos." then begin
            InventorySetup.Validate("Item Nos.", GetGlobalNoSeriesCode);
            InventorySetup.Modify(true);
        end;
    end;

    local procedure FindGeneralPostingSetupInvtFull(var GeneralPostingSetup: Record "General Posting Setup")
    var
        SearchPostingType: Option All,Sales,Purchase;
    begin
        GeneralPostingSetup.SetFilter("Gen. Bus. Posting Group", '<>%1', '');
        GeneralPostingSetup.SetFilter("Gen. Prod. Posting Group", '<>%1', '');
        if SearchPostingType <> SearchPostingType::Purchase then begin
            GeneralPostingSetup.SetFilter("Sales Account", '<>%1', '');
            GeneralPostingSetup.SetFilter("Sales Credit Memo Account", '<>%1', '');
            GeneralPostingSetup.SetFilter("Sales Prepayments Account", '<>%1', '');
        end;
        if SearchPostingType <> SearchPostingType::Sales then begin
            GeneralPostingSetup.SetFilter("Purch. Account", '<>%1', '');
            GeneralPostingSetup.SetFilter("Purch. Credit Memo Account", '<>%1', '');
            GeneralPostingSetup.SetFilter("Purch. Prepayments Account", '<>%1', '');
        end;
        GeneralPostingSetup.SetFilter("COGS Account", '<>%1', '');
        GeneralPostingSetup.SetFilter("COGS Account (Interim)", '<>''''');
        GeneralPostingSetup.SetFilter("Inventory Adjmt. Account", '<>%1', '');
        GeneralPostingSetup.SetFilter("Direct Cost Applied Account", '<>%1', '');
        GeneralPostingSetup.SetFilter("Overhead Applied Account", '<>%1', '');
        GeneralPostingSetup.SetFilter("Purchase Variance Account", '<>%1', '');
        if not GeneralPostingSetup.FindFirst then begin
            GeneralPostingSetup.SetRange("Sales Prepayments Account");
            GeneralPostingSetup.SetRange("Purch. Prepayments Account");
            if GeneralPostingSetup.FindFirst then begin
                SetGeneralPostingSetupPrepAccounts(GeneralPostingSetup);
                GeneralPostingSetup.Modify(true);
            end else begin
                GeneralPostingSetup.SetRange("COGS Account (Interim)");
                GeneralPostingSetup.SetRange("Direct Cost Applied Account");
                GeneralPostingSetup.SetRange("Overhead Applied Account");
                GeneralPostingSetup.SetRange("Purchase Variance Account");
                if GeneralPostingSetup.FindFirst then begin
                    SetGeneralPostingSetupInvtAccounts(GeneralPostingSetup);
                    SetGeneralPostingSetupMfgAccounts(GeneralPostingSetup);
                    SetGeneralPostingSetupPrepAccounts(GeneralPostingSetup);
                    GeneralPostingSetup.Modify(true);
                end else begin
                    GeneralPostingSetup.SetRange("Purch. Account");
                    GeneralPostingSetup.SetRange("Purch. Credit Memo Account");
                    if GeneralPostingSetup.FindFirst then begin
                        SetGeneralPostingSetupInvtAccounts(GeneralPostingSetup);
                        SetGeneralPostingSetupMfgAccounts(GeneralPostingSetup);
                        SetGeneralPostingSetupPrepAccounts(GeneralPostingSetup);
                        SetGeneralPostingSetupPurchAccounts(GeneralPostingSetup);
                        GeneralPostingSetup.Modify(true);
                    end else
                        FindGeneralPostingSetupInvtBase(GeneralPostingSetup);
                end;
            end;
        end;
    end;

    local procedure SetGeneralPostingSetupPrepAccounts(var GeneralPostingSetup: Record "General Posting Setup")
    begin
        if GeneralPostingSetup."Sales Prepayments Account" = '' then
            GeneralPostingSetup.Validate("Sales Prepayments Account", CreateGLAccountNo);
        if GeneralPostingSetup."Purch. Prepayments Account" = '' then
            GeneralPostingSetup.Validate("Purch. Prepayments Account", CreateGLAccountNo);
    end;

    local procedure CreateGLAccountNo(): Code[20]
    var
        GLAccount: Record "G/L Account";
    begin
        CreateGLAccount(GLAccount);
        exit(GLAccount."No.");
    end;

    local procedure CreateGLAccount(var GLAccount: Record "G/L Account")
    begin
        GLAccount.Init();
        // Prefix a number to fix errors for local build.
        GLAccount.Validate(
          "No.",
          PadStr(
            '1' + GenerateRandomCode(GLAccount.FieldNo("No."), DATABASE::"G/L Account"), MaxStrLen(GLAccount."No."), '0'));
        GLAccount.Validate(Name, GLAccount."No.");  // Enter No. as Name because value is not important.
        GLAccount.Insert(true);
    end;

    local procedure GenerateRandomCode(FieldNo: Integer; TableNo: Integer): Code[10]
    var
        RecRef: RecordRef;
        FieldRef: FieldRef;
    begin
        // Create a random and unique code for the any code field.
        RecRef.Open(TableNo, true, CompanyName);
        Clear(FieldRef);
        FieldRef := RecRef.Field(FieldNo);

        repeat
            if FieldRef.Length < 10 then
                FieldRef.SetRange(CopyStr(GenerateGUID, 10 - FieldRef.Length + 1)) // Cut characters on the left side.
            else
                FieldRef.SetRange(GenerateGUID);
        until RecRef.IsEmpty;

        exit(FieldRef.GetFilter)
    end;

    local procedure GenerateGUID(): Code[10]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        NoSeriesMgt: Codeunit NoSeriesManagement;
    begin
        if not NoSeries.Get('GUID') then begin
            NoSeries.Init();
            NoSeries.Validate(Code, 'GUID');
            NoSeries.Validate("Default Nos.", true);
            NoSeries.Validate("Manual Nos.", true);
            NoSeries.Insert(true);

            CreateNoSeriesLine(NoSeriesLine, NoSeries.Code, '', '');
        end;

        exit(NoSeriesMgt.GetNextNo(NoSeries.Code, WorkDate, true));
    end;

    local procedure CreateNoSeriesLine(var NoSeriesLine: Record "No. Series Line"; SeriesCode: Code[20]; StartingNo: Code[20]; EndingNo: Code[20])
    var
        RecRef: RecordRef;
    begin
        NoSeriesLine.Init();
        NoSeriesLine.Validate("Series Code", SeriesCode);
        RecRef.GetTable(NoSeriesLine);
        NoSeriesLine.Validate("Line No.", 10000);

        if StartingNo = '' then
            NoSeriesLine.Validate("Starting No.", PadStr(InsStr(SeriesCode, '00000000', 3), 10))
        else
            NoSeriesLine.Validate("Starting No.", StartingNo);

        if EndingNo = '' then
            NoSeriesLine.Validate("Ending No.", PadStr(InsStr(SeriesCode, '99999999', 3), 10))
        else
            NoSeriesLine.Validate("Ending No.", EndingNo);

        NoSeriesLine.Insert(true)
    end;

    local procedure CreateVATPostingSetupWithAccounts(var VATPostingSetup: Record "VAT Posting Setup"; VATCalculationType: Enum "Tax Calculation Type"; VATRate: Decimal)
    var
        VATBusinessPostingGroup: Record "VAT Business Posting Group";
        VATProductPostingGroup: Record "VAT Product Posting Group";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        if IsHandled then
            exit;

        VATPostingSetup.Init();
        CreateVATBusinessPostingGroup(VATBusinessPostingGroup);
        CreateVATProductPostingGroup(VATProductPostingGroup);
        VATPostingSetup.Validate("VAT Bus. Posting Group", VATBusinessPostingGroup.Code);
        VATPostingSetup.Validate("VAT Prod. Posting Group", VATProductPostingGroup.Code);
        VATPostingSetup.Validate("VAT Calculation Type", VATCalculationType);
        VATPostingSetup.Validate("VAT %", VATRate);
        VATPostingSetup.Validate("VAT Identifier",
          GenerateRandomCode(VATPostingSetup.FieldNo("VAT Identifier"), DATABASE::"VAT Posting Setup"));
        VATPostingSetup.Validate("Sales VAT Account", CreateGLAccountNo);
        VATPostingSetup.Validate("Purchase VAT Account", CreateGLAccountNo);
        VATPostingSetup.Validate("Tax Category", 'S');
        VATPostingSetup.Insert(true);
    end;

    local procedure CreateVATBusinessPostingGroup(var VATBusinessPostingGroup: Record "VAT Business Posting Group")
    begin
        VATBusinessPostingGroup.Init();
        VATBusinessPostingGroup.Validate(
          Code,
          CopyStr(GenerateRandomCode(VATBusinessPostingGroup.FieldNo(Code), DATABASE::"VAT Business Posting Group"),
            1, 20));

        // Validating Code as Name because value is not important.
        VATBusinessPostingGroup.Validate(Description, VATBusinessPostingGroup.Code);
        VATBusinessPostingGroup.Insert(true);
    end;

    local procedure CreateVATProductPostingGroup(var VATProductPostingGroup: Record "VAT Product Posting Group")
    begin

        VATProductPostingGroup.Init();
        VATProductPostingGroup.Validate(
          Code,
          CopyStr(GenerateRandomCode(VATProductPostingGroup.FieldNo(Code), DATABASE::"VAT Product Posting Group"),
            1, 20));

        // Validating Code as Name because value is not important.
        VATProductPostingGroup.Validate(Description, VATProductPostingGroup.Code);
        VATProductPostingGroup.Insert(true);

    end;

    local procedure GetGlobalNoSeriesCode(): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        // Init, get the global no series
        if not NoSeries.Get('GLOBAL') then begin
            NoSeries.Init();
            NoSeries.Validate(Code, 'GLOBAL');
            NoSeries.Validate("Default Nos.", true);
            NoSeries.Validate("Manual Nos.", true);
            NoSeries.Insert(true);
            CreateNoSeriesLine(NoSeriesLine, NoSeries.Code, '', '');
        end;

        exit(NoSeries.Code)
    end;

    local procedure SetGeneralPostingSetupInvtAccounts(var GeneralPostingSetup: Record "General Posting Setup")
    begin
        if GeneralPostingSetup."COGS Account" = '' then
            GeneralPostingSetup.Validate("COGS Account", CreateGLAccountNo);
        if GeneralPostingSetup."COGS Account (Interim)" = '' then
            GeneralPostingSetup.Validate("COGS Account (Interim)", CreateGLAccountNo);
        if GeneralPostingSetup."Inventory Adjmt. Account" = '' then
            GeneralPostingSetup.Validate("Inventory Adjmt. Account", CreateGLAccountNo);
        if GeneralPostingSetup."Invt. Accrual Acc. (Interim)" = '' then
            GeneralPostingSetup.Validate("Invt. Accrual Acc. (Interim)", CreateGLAccountNo);
    end;

    local procedure SetGeneralPostingSetupMfgAccounts(var GeneralPostingSetup: Record "General Posting Setup")
    begin
        if GeneralPostingSetup."Direct Cost Applied Account" = '' then
            GeneralPostingSetup.Validate("Direct Cost Applied Account", CreateGLAccountNo);
        if GeneralPostingSetup."Overhead Applied Account" = '' then
            GeneralPostingSetup.Validate("Overhead Applied Account", CreateGLAccountNo);
        if GeneralPostingSetup."Purchase Variance Account" = '' then
            GeneralPostingSetup.Validate("Purchase Variance Account", CreateGLAccountNo);
    end;

    local procedure SetGeneralPostingSetupPurchAccounts(var GeneralPostingSetup: Record "General Posting Setup")
    begin
        if GeneralPostingSetup."Purch. Account" = '' then
            GeneralPostingSetup.Validate("Purch. Account", CreateGLAccountNo);
        if GeneralPostingSetup."Purch. Line Disc. Account" = '' then
            GeneralPostingSetup.Validate("Purch. Line Disc. Account", CreateGLAccountNo);
        if GeneralPostingSetup."Purch. Inv. Disc. Account" = '' then
            GeneralPostingSetup.Validate("Purch. Inv. Disc. Account", CreateGLAccountNo);
        if GeneralPostingSetup."Purch. Credit Memo Account" = '' then
            GeneralPostingSetup.Validate("Purch. Credit Memo Account", CreateGLAccountNo);
    end;

    local procedure FindGeneralPostingSetupInvtBase(var GeneralPostingSetup: Record "General Posting Setup")
    var
        SearchPostingType: Option All,Sales,Purchase;
    begin
        GeneralPostingSetup.SetFilter("Gen. Bus. Posting Group", '<>%1', '');
        GeneralPostingSetup.SetFilter("Gen. Prod. Posting Group", '<>%1', '');
        GeneralPostingSetup.SetFilter("COGS Account", '<>%1', '');
        GeneralPostingSetup.SetFilter("Inventory Adjmt. Account", '<>%1', '');
        if SearchPostingType <> SearchPostingType::Purchase then
            GeneralPostingSetup.SetFilter("Sales Account", '<>%1', '');
        if SearchPostingType <> SearchPostingType::Sales then
            GeneralPostingSetup.SetFilter("Purch. Account", '<>%1', '');
        if not GeneralPostingSetup.FindFirst then begin
            GeneralPostingSetup.SetRange("Purch. Account");
            GeneralPostingSetup.SetRange("Inventory Adjmt. Account");
            if GeneralPostingSetup.FindFirst then begin
                GeneralPostingSetup.Validate("Purch. Account", CreateGLAccountNo);
                GeneralPostingSetup.Validate("Inventory Adjmt. Account", CreateGLAccountNo);
                GeneralPostingSetup.Modify(true);
            end else
                CreateGeneralPostingSetupInvt(GeneralPostingSetup);
        end;
    end;

    local procedure CreateGeneralPostingSetupInvt(var GeneralPostingSetup: Record "General Posting Setup")
    var
        GenBusinessPostingGroup: Record "Gen. Business Posting Group";
        GenProductPostingGroup: Record "Gen. Product Posting Group";
    begin
        CreateGenBusPostingGroup(GenBusinessPostingGroup);
        CreateGenProdPostingGroup(GenProductPostingGroup);
        CreateGeneralPostingSetup(GeneralPostingSetup, GenBusinessPostingGroup.Code, GenProductPostingGroup.Code);
        GeneralPostingSetup.Validate("Sales Account", CreateGLAccountNo);
        GeneralPostingSetup.Validate("Purch. Account", CreateGLAccountNo);
        GeneralPostingSetup.Validate("COGS Account", CreateGLAccountNo);
        GeneralPostingSetup.Validate("Inventory Adjmt. Account", CreateGLAccountNo);
        GeneralPostingSetup.Modify(true);
    end;

    local procedure CreateGenBusPostingGroup(var GenBusinessPostingGroup: Record "Gen. Business Posting Group")
    begin
        GenBusinessPostingGroup.Init();
        GenBusinessPostingGroup.Validate(
          Code,
          CopyStr(GenerateRandomCode(GenBusinessPostingGroup.FieldNo(Code), DATABASE::"Gen. Business Posting Group"),
            1, 20));

        // Validating Code as Name because value is not important.
        GenBusinessPostingGroup.Validate(Description, GenBusinessPostingGroup.Code);
        GenBusinessPostingGroup.Insert(true);
    end;

    local procedure CreateGeneralPostingSetup(var GeneralPostingSetup: Record "General Posting Setup"; GenBusPostingGroup: Code[20]; GenProdPostingGroup: Code[20])
    begin
        GeneralPostingSetup.Init();
        GeneralPostingSetup.Validate("Gen. Bus. Posting Group", GenBusPostingGroup);
        GeneralPostingSetup.Validate("Gen. Prod. Posting Group", GenProdPostingGroup);
        GeneralPostingSetup.Insert(true);
    end;

    local procedure CreateGenProdPostingGroup(var GenProductPostingGroup: Record "Gen. Product Posting Group")
    begin
        GenProductPostingGroup.Init();
        GenProductPostingGroup.Validate(
          Code,
          CopyStr(GenerateRandomCode(GenProductPostingGroup.FieldNo(Code), DATABASE::"Gen. Product Posting Group"),
            1, 20));

        // Validating Code as Name because value is not important.
        GenProductPostingGroup.Validate(Description, GenProductPostingGroup.Code);
        GenProductPostingGroup.Insert(true);
    end;

    local procedure CreateInventoryPostingGroup(var InventoryPostingGroup: Record "Inventory Posting Group")
    begin
        Clear(InventoryPostingGroup);
        InventoryPostingGroup.Init();
        InventoryPostingGroup.Validate(Code,
          GenerateRandomCode(InventoryPostingGroup.FieldNo(Code), DATABASE::"Inventory Posting Group"));
        InventoryPostingGroup.Validate(Description, InventoryPostingGroup.Code);
        InventoryPostingGroup.Insert(true);
    end;


}