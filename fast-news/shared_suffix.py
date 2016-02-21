def shared_suffix(strings):
    if len(strings) == 0:
        return ""
    elif len(strings) == 1:
        return strings[0]
    elif len(strings) == 2:
        i = 0
        s1 = strings[0]
        s2 = strings[1]
        while i+1 <= min(len(s1), len(s2)) and s1[len(s1) - i - 1] == s2[len(s2) - i - 1]:
            i += 1
        return s1[len(s1)-i:]
    else:
        first_half = shared_suffix(strings[:len(strings)/2])
        second_half = shared_suffix(strings[len(strings)/2:])
        return shared_suffix([first_half, second_half])

if __name__ == '__main__':
    assert shared_suffix([]) == ""
    assert shared_suffix(["abc", "abc"]) == "abc"
    assert shared_suffix(["abc", "xabc"]) == "abc"
    assert shared_suffix(["yabc", "xyzabc"]) == "abc"
    assert shared_suffix(["xabc", "yabc", "xyzabc"]) == "abc"
    assert shared_suffix(["yabc", "ihep"]) == ""
    assert shared_suffix(["xabc", "yabc", "ihep"]) == ""

