#!/usr/bin/awk -f

# The caller must pass arg: daemon-parm.txt
# The resulting code is output into daemon-parm.h

BEGIN {
    heading = "/* DO NOT EDIT THIS FILE!  It is auto-generated from a list of values in " ARGV[1] "! */"
    sect = psect = defines = accessors = prior_ptype = ""
    values = "\nstatic const all_vars Defaults = {\n    { /* Globals: */\n"
    params = "\nstatic struct parm_struct parm_table[] = {"
    exp_line = "\n/********** EXP **********/\n"
    tdstruct = "typedef struct {"
}

/^\s*$/ { next }
/^#/ { next }

/^Globals:/ {
    if (defines != "") {
	print "The Globals section must come first!"
	defines = ""
	exit
    }
    defines = tdstruct
    exps = exp_values = exp_line
    sect = "GLOBAL"
    psect = ", P_GLOBAL, &Vars.g."
    next
}

/^Locals:/ {
    if (sect == "") {
	print "The Locals section must come after the Globals!"
	exit
    }
    defines = defines exps "} global_vars;\n\n" tdstruct
    values = values exp_values "\n    }, { /* Locals: */\n"
    exps = exp_values = exp_line
    sect = "LOCAL"
    psect = ", P_LOCAL, &Vars.l."
    next
}

/^(STRING|PATH|INTEGER|ENUM|BOOL)/ {
    ptype = $1
    name = $2
    $1 = $2 = ""
    sub(/^[ \t]+/, "")

    if (ptype != prior_ptype) {
	defines = defines "\n/********** " ptype " **********/\n"
	values = values "\n/********** " ptype " **********/\n"
	params = params "\n"
	accessors = accessors "\n"
	prior_ptype = ptype
    }

    if (ptype == "STRING" || ptype == "PATH") {
	atype = "STRING"
	vtype = "char*"
    } else if (ptype == "BOOL") {
	atype = vtype = "BOOL"
    } else {
	atype = "INTEGER"
	vtype = "int"
    }

    # We have 2 variables that don't match their conf string. Oh well...
    if (name == "bind_address")
	spname = "address"
    else if (name == "rsync_port")
	spname = "port"
    else {
	spname = name
	gsub(/_/, " ", spname)
	gsub(/-/, "", name)
    }

    if (ptype == "ENUM")
	enum = "enum_" name
    else
	enum = "NULL"

    defines = defines "\t" vtype " " name ";\n"
    values = values "\t" $0 ", /* " name " */\n"
    params = params " {\"" spname "\", P_" ptype psect name ", " enum ", 0},\n"
    accessors = accessors "FN_" sect "_" atype "(lp_" name ", " name ")\n"

    if (vtype == "char*") {
	exps = exps "\tBOOL " name "_EXP;\n"
	exp_values = exp_values "\tFalse, /* " name "_EXP */\n"
    }

    next
}

/./ {
    print "Extraneous line:" $0
    defines = ""
    exit
}

END {
    if (sect != "" && defines != "") {
	defines = defines exps "} local_vars;\n\n"
	defines = defines tdstruct "\n\tglobal_vars g;\n\tlocal_vars l;\n} all_vars;\n"
	values = values exp_values "\n    }\n};\n\nstatic all_vars Vars;\n"
	params = params "\n {NULL, P_BOOL, P_NONE, NULL, NULL, 0}\n};\n"
	print heading "\n\n" defines values params accessors > "daemon-parm.h"
    } else {
	print "Failed to parse the data in " ARGV[1]
	exit 1
    }
}
