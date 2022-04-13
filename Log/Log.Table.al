table 70100 "PTE Item Adjust Cost Log Entry"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
            DataClassification = ToBeClassified;
        }
        field(5; Processed; Boolean)
        {
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(12; "Item No."; Code[20])
        {
            TableRelation = Item;
            DataClassification = ToBeClassified;
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(ItemNoProcessed; "Item No.", Processed) { }
    }
}