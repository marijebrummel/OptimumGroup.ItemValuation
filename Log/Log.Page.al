page 70100 "PTE Item Adjust Cost Log Entr."
{
    Caption = 'Item Adjust Cost Log Entries';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "PTE Item Adjust Cost Log Entry";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(List)
            {
                field("Item No."; Rec."Item No.") { ApplicationArea = All; }
                field(Processed; Rec.Processed) { ApplicationArea = All; }
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Item)
            {
                Caption = 'Item Card';
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                Image = Item;
                RunObject = page "Item Card";
                RunPageLink = "No." = field("Item No.");
            }
        }
        area(Processing)
        {
            action(Process)
            {
                Caption = 'Process (Manually)';
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                Image = Process;

                trigger OnAction();
                var
                    RunAdjustCost: Codeunit "PTE Run Item Adjust Cost";
                    ConfirmQst: Label 'Are you sure you want to process manually?';
                begin
                    if Confirm(ConfirmQst, true) then
                        RunAdjustCost.Run();
                end;
            }
        }
    }
}