codeunit 62026 "PTE Adjust Cost Event Subs."
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterUpdateAdjmtProp', '', false, false)]
    local procedure OnAfterUpdateAdjmtProp(var ValueEntry: Record "Value Entry")
    begin
        CreateLogEntryIfNotExist(ValueEntry."Item No.");
    end;

    local procedure CreateLogEntryIfNotExist(Value: Code[20])
    var
        ItemAdjustCostLogEntry: Record "PTE Item Adjust Cost Log Entry";
    begin
        ItemAdjustCostLogEntry.SetRange("Item No.", Value);
        ItemAdjustCostLogEntry.SetRange(Processed, false);
        if not ItemAdjustCostLogEntry.IsEmpty then              // A record already exists and this item will be processed in the next run
            exit;

        ItemAdjustCostLogEntry.Init();
        ItemAdjustCostLogEntry."Entry No." := 0;
        ItemAdjustCostLogEntry."Item No." := Value;
        ItemAdjustCostLogEntry.Processed := false;
        ItemAdjustCostLogEntry.Insert();
    end;
}