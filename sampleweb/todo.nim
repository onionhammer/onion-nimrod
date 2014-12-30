# Imports
import jester, asyncdispatch, templates

# Views
import views/layout

# Models

# Actions
proc index: string =
    "hello world"

# Routes
routes:
    get "/":
        resp index()

runForever()