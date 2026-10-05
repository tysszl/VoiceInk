# dmgbuild settings for the VoiceInk installer DMG.
# App path and background path come from the environment so build-signed.sh
# can point at the freshly built .app. dmgbuild writes the .DS_Store directly,
# so the picture background applies reliably. A sibling [email protected]
# is auto-detected for Retina.
import os

application = os.environ["DMG_APP"]
appname = os.path.basename(application)

volume_name = "VoiceInk"
format = "UDZO"

background = os.environ["DMG_BG"]
window_rect = ((200, 120), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 120
text_size = 13

files = [application]
symlinks = {"Applications": "/Applications"}
icon_locations = {
    appname: (165, 200),
    "Applications": (495, 200),
}
hide_extension = [appname]
