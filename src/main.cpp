#include <wx/wx.h>
#include "frames/MainFrame.h"

class MyApp : public wxApp{
    public:
        virtual bool OnInit() override{
            MainFrame* mainframe = new MainFrame("Example");
            mainframe->Show(true);
            return true;
        }
        virtual void OnFatalException() override{
            wxMessageBox("Error", "Error", wxOK | wxICON_ERROR);
        }

};

wxIMPLEMENT_APP(MyApp);