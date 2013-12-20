# Fields
const x = 5


# Test substring
static:
    assert "test".substring(3)   == "t"
    assert "test".substring(3,2) == "t"
    assert "test".substring(1,2) == "es"


# Various parsing tests
when false:
    block: #no_substitution
        proc actual: string = tmpl html"""
            <p>Test!</p>
        """
        const expected = html"""
            <p>Test!</p>
        """
        echo actual()
        assert actual() == expected

    block: #basic
        proc actual: string = tmpl html"""
            <p>Test $$x</p>
            $x
        """
        const expected = html"""
            <p>Test $x</p>
            5
        """
        echo actual()
        assert actual() == expected

    block: #expression
        proc actual: string = tmpl html"""
            <p>Test $$(x * 5)</p>
            $(x * 5)
        """
        const expected = html"""
            <p>Test $(x * 5)</p>
            25
        """
        echo actual()
        assert actual() == expected

    block: #forIn
        proc actual: string = tmpl html"""
            <p>Test for</p>
            <ul>
            $for y in 0..2 {
                <li>$y</li>
            }
            </ul>
        """
        const expected = html"""
            <p>Test for</p>
            <ul>
                <li>0</li>
                <li>1</li>
                <li>2</li>
            </ul>
        """
        echo actual()
        assert actual() == expected

    block: #while
        proc actual: string = tmpl html"""
            <p>Test while/stmt</p>
            <ul>
            ${ var y = 0 }
            $while y < 4 {
                <li>$y</li>
                ${ inc(y) }
            }
            </ul>
        """
        const expected = html"""
            <p>Test while/stmt</p>
            <ul>
                <li>0</li>
                <li>1</li>
                <li>2</li>
                <li>3</li>
            </ul>
        """
        echo actual()
        assert actual() == expected


block: #ifElifElse
    proc actual: string = tmpl html"""
        <p>Test if/elif/else</p>
        $if x == 8 {
            <div>x is 8!</div>
        }
        $elif x == 7 {
            <div>x is 7!</div>
        }
        $else {
            <div>x is neither!</div>
        }
    """
    const expected = html"""
        <p>Test if/elif/else</p>
            <div>x is neither!</div>
    """
    echo actual()
    assert actual() == expected


when false:

    block: #caseOfElse
        proc actual: string = tmpl html"""
            <p>Test case</p>
            $case x
            $of 5 {
                <div>x == 5</div>
            }
            $of 6 {
                <div>x == 6</div>
            }
            $else {
                <div>x == ?</div>
            }
        """
        const expected = html"""
            <p>Test case</p>
            <div>x == 5</div>
        """
        echo actual()
        assert actual() == expected