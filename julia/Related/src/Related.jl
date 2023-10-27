module Related

using JSON3
using StructTypes
using Dates
using PrecompileTools
using StaticArrays

const topn = 5

export main

struct PostData
    _id::String
    title::String
    tags::Vector{Symbol}
end

struct RelatedPost
    _id::String
    tags::Vector{Symbol}
    related::SVector{topn, PostData}
end

StructTypes.StructType(::Type{PostData}) = StructTypes.Struct()

function fastmaxindex(xs::Vector{T}) where {T}
    # each element is a pair idx => val
    maxs = MVector(ntuple(_ -> 1 => zero(T), topn))
    top = maxs[1][2]
    for (i, x) in enumerate(xs)
        if x > top
            maxs[1] = (i => x)
            for j in 2:topn
                 if maxs[j-1][2] > maxs[j][2]
                    maxs[j-1], maxs[j] = maxs[j], maxs[j-1]
                end
            end
            top = maxs[1][2]
        end
    end
    reverse!(maxs)
    return SVector(ntuple(i -> maxs[i][1], topn))
end

function related(posts)
    T = UInt32
    # key is every possible "tag" used in all posts
    # value is indicies of all "post"s that used this tag
    tagmap = Dict{Symbol,Vector{T}}()
    for (idx, post) in enumerate(posts)
        for tag in post.tags
            tags = get!(() -> T[], tagmap, tag)
            push!(tags, idx)
        end
    end

    relatedposts = Vector{RelatedPost}(undef, length(posts))
    taggedpostcount = Vector{T}(undef, length(posts))

    # maxn = MVector{topn, Int}(undef)
    # maxv = MVector{topn, T}(undef)
    
    for (i, post) in enumerate(posts)
        taggedpostcount .= 0
        # for each post (`i`-th)
        # and every tag used in the `i`-th post
        # give all related post +1 in `taggedpostcount` shadow vector
        for tag in post.tags
            for idx in tagmap[tag]
                taggedpostcount[idx] += one(T)
            end
        end

        # don't self count
        taggedpostcount[i] = 0

        maxn = fastmaxindex(taggedpostcount)

        relatedpost = RelatedPost(post._id, post.tags, SVector{topn}(@view posts[maxn]))
        relatedposts[i] = relatedpost
    end

    return relatedposts
end

function main()
    json_string = read(@__DIR__()*"/../../../posts.json", String)
    posts = JSON3.read(json_string, Vector{PostData})
    
    start = now()       
    all_related_posts = related(posts)
    println("Processing time (w/o IO): $(now() - start)")

    open(@__DIR__()*"/../../../related_posts_julia.json", "w") do f
        JSON3.write(f, all_related_posts)
    end
end


@compile_workload begin
    print("Precompiling main workload: ")
    main()
end


end # module Related
