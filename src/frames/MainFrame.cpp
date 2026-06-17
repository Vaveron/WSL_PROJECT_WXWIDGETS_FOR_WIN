#include "MainFrame.h"
MainFrame::MainFrame(const wxString& title) : wxFrame(nullptr, wxID_ANY, title){
    SetSize(300, 300);
    Centre();
    wxPanel* panel = new wxPanel(this);



}