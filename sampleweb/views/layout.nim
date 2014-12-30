import templates

# Views
template master*(title, content: string): string = tmpli html"""
    <!doctype html>
    <title>$title</title>
    <div id=container>
        <h1>$title</h1>
        <div id=content>
            $content
        </div>
    </div>
    """