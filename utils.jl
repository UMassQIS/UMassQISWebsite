using Dates

@delay function hfun_recentposts(params)
    postdir = only(params)
    list = readdir(postdir)
    filter!(f -> endswith(f, ".md"), list)
    dates = Vector{Date}(undef, length(list))
    titles = Vector{String}(undef, length(list))
    links = Vector{String}(undef, length(list))
    for (i, file) in enumerate(list)
        postname = splitext(basename(file))[1]
        url = postdir * "/" * postname
        pubdate = pagevar(url, :published)
        dates[i] = isnothing(pubdate) ? Date(1999) : Date(pubdate, dateformat"d U Y")
        titles[i] = something(pagevar(url, :title), "Post $i")
        externallink = pagevar(url, :external)
        links[i] = isnothing(externallink) ? ("../" * url * "/") : externallink
    end
    perm = sortperm(dates, rev=true)
    io = IOBuffer()
    for i in perm
        write(io, """<p><a href="$(links[i])">$(titles[i])</a>""")
        !isnothing(dates[i]) && write(io, " ($(monthname(dates[i])) $(year(dates[i])))")
        write(io, "</p>\n")
    end
    return String(take!(io))
end

##

import YAML
import LightXML
import Downloads
using Dates
using Mustache

###
# arxiv bibliography
###

const arxiv_export_url = mt"http://arxiv.org/a/{{:arxiv_id}}.atom"

function get_arxiv_bibliography(arxiv_id)
    xml = Downloads.download(render(arxiv_export_url, (;arxiv_id)), IOBuffer()) |> take! |> String
    LightXML.parse_string(xml)
end

##
firstcon(x) = isempty(x) ? nothing : LightXML.content(first(x))
doilink(e) = LightXML.attribute([l for l in e["link"] if LightXML.attribute(l, "title") == "doi"][1], "href")
fixup(str) = replace(str, "\n" => " ")
#getdate(e) = parse(DateTime, firstcon(e["published"]), dateformat"yyyy-mm-dd\THH:MM:SS\Z")
getdate(e) = parse(DateTime, firstcon(e["published"])[1:end-6], dateformat"yyyy-mm-dd\THH:MM:SS")

function arxiv_bibliography(arxiv_ids)
    entries = []
    #io = stdout
    io = IOBuffer()
    for arxiv_id in arxiv_ids
        ab = get_arxiv_bibliography(arxiv_id)
        feed = LightXML.root(ab)
        append!(entries, feed["entry"])
        sleep(1)
    end
    entries = sort(entries, by = e -> getdate(e), rev=true)
    for e in entries
        authors = [firstcon(a["name"]) for a in e["author"]]
        #"Stefan Krastanov" ∈ authors || continue
        date = Dates.format(getdate(e), ISODateFormat)
        _journalref = firstcon(e["journal_ref"])
        journalref = if isnothing(_journalref)
            "<!--preprint--> $(date)"
        else
            doi = doilink(e)
            """<a href="$(doi)">$(_journalref)</a>"""
        end
        abstract = firstcon(e["summary"])
        whitespaces = findall(" ", abstract)
        cutoff = whitespaces[min(50, length(whitespaces))]
        summary = abstract[1:cutoff.stop]
        leftover = abstract[cutoff.stop+1:end]
        block ="""
        <div class="publication">
        <div class="well">
          <h3><a href="$(firstcon(e["id"]))">$(fixup(firstcon(e["title"])))</a></h3>
          <p><em>$(join(authors, ", "))</em></p>
          <p><strong>$(journalref)</strong></p>
          <details>
            <summary>$(summary) <small>... [click to read more]</small></summary>
            <p>$(leftover)</p>
          </details>
        </div>
        </div>
        """
        print(io, block, "\n")
    end
    String(take!(io))
end

function hfun_arxiv_bibliography_krastanov()
    arxiv_bibliography(["krastanov_s_1"])
end

function hfun_arxiv_bibliography_amherst()
    return ""
    arxiv_bibliography(["towsley_d_1", "krastanov_s_1", "rozpedek_f_1", "niffenegger_r_1", "vasseur_r_1", "vardoyan_g_1"])
end
